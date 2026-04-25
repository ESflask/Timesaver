import AVFoundation
import MediaPlayer
import UIKit
import AudioToolbox

/// アラーム音の再生・停止・振動切り替えを管理
class AlarmSoundManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var systemSoundTimer: Timer?
    @Published var isPlaying = false
    @Published var isVibrating = false
    @Published var isSilencePlaying = false

    /// 無音ループの各再生完了時に呼ばれるコールバック（時刻チェック用）
    var onSilenceLoopTick: (() -> Void)?

    // MARK: - 無音ループ再生（バックグラウンド維持用）

    /// 無音ファイルを手動ループ再生してアプリのサスペンドを防ぐ
    /// 再生完了のたびに onSilenceLoopTick を呼び出し、時刻チェックを可能にする
    func startSilenceLoop() {
        guard !isSilencePlaying else { return }
        configureAudioSession()

        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            print("silence.wav が見つかりません")
            return
        }

        do {
            silencePlayer = try AVAudioPlayer(contentsOf: url)
            silencePlayer?.numberOfLoops = 0   // 手動ループ（delegateで再開）
            silencePlayer?.volume = 1.0        // 音源自体が無音なので音量は維持
            silencePlayer?.delegate = self
            silencePlayer?.prepareToPlay()
            isSilencePlaying = silencePlayer?.play() == true
            disableRemoteControls()
        } catch {
            print("無音ループ再生に失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - AVAudioPlayerDelegate

    /// 無音ファイル再生完了時: 時刻チェックコールバックを実行し、再度再生
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard isSilencePlaying else { return }
        // 時刻チェックコールバック（AlarmScheduler が設定時刻到達を検知）
        DispatchQueue.main.async { [weak self] in
            self?.onSilenceLoopTick?()
        }
        // 無音ファイルを再度再生
        player.play()
    }

    /// ロック画面のメディアコントロールを無効化し、停止されても自動再開
    private func disableRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 一時停止を受け取っても再生を再開する
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.silencePlayer?.play()
            return .success
        }

        // 停止コマンドも同様
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.silencePlayer?.play()
            return .success
        }

        // 再生ボタンも念のためハンドル
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.silencePlayer?.play()
            return .success
        }

        // 無音再生中はNow Playing情報を最小化
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Infinite Wake — 待機中"
        ]
    }

    /// アラーム発動時にNow Playingを更新してタップを促す
    func updateNowPlayingForAlarm() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "ここをタップしてアプリを開く",
            MPMediaItemPropertyArtist: "Infinite Wake"
        ]

        // アイコン画像（後で差し替え用のプレースホルダー）
        if let image = UIImage(named: "nowplaying_icon") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 無音ループを停止（アラーム解除・リセット時）
    func stopSilenceLoop() {
        silencePlayer?.stop()
        silencePlayer = nil
        isSilencePlaying = false
        clearNowPlayingInfo()

        // リモートコマンドのハンドラを解除
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
    }

    // MARK: - 音声再生

    /// アラーム音を適度な音量でループ再生
    func playAlarm() {
        guard !isPlaying else { return }

        if !isSilencePlaying {
            startSilenceLoop()
        }

        // オーディオセッションを設定（サイレントモードでも鳴るように）
        configureAudioSession()
        // システム音量をアラーム用に設定
        setSystemVolume(to: 0.33)
        // ロック画面のNow Playingにタップを促す情報を表示
        updateNowPlayingForAlarm()

        if let url = alarmSoundURL() {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1  // 無限ループ
                audioPlayer?.volume = 1.0        // 最大音量
                audioPlayer?.prepareToPlay()
                isPlaying = audioPlayer?.play() == true
                if !isPlaying {
                    print("アラーム音の再生開始に失敗しました")
                    playGeneratedAlarm()
                }
            } catch {
                print("アラーム音の再生に失敗: \(error.localizedDescription)")
                playGeneratedAlarm()
            }
        } else {
            print("alarm_sound が見つからないため合成アラーム音を使用します")
            playGeneratedAlarm()
        }
    }

    /// アラーム音を停止
    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSoundTimer?.invalidate()
        systemSoundTimer = nil
        isPlaying = false
    }

    /// バンドル内のアラーム音を拡張子違いも含めて探す
    private func alarmSoundURL() -> URL? {
        for fileExtension in ["mp3", "m4a", "wav", "caf", "aiff"] {
            if let url = Bundle.main.url(forResource: "alarm_sound", withExtension: fileExtension) {
                return url
            }
        }
        return nil
    }

    // MARK: - 振動

    /// iPhoneの振動をループ再生（覚醒アクション完了まで止まらない）
    /// RunLoop の .common モードに登録し、スクロール中でも振動が途切れないようにする
    func startVibration() {
        guard !isVibrating else { return }
        isVibrating = true
        triggerVibration()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isVibrating else { return }
            self.triggerVibration()
        }
        RunLoop.main.add(timer, forMode: .common)
        vibrationTimer = timer
    }

    /// 振動を停止
    func stopVibration() {
        isVibrating = false
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    /// 1回の振動を発生させる
    private func triggerVibration() {
        // システムの標準バイブレーションを呼び出し（バックグラウンド・スリープ時でも鳴動可能）
        AudioServicesPlaySystemSound(SystemSoundID(4095))
        
        // 短い間隔で連続振動させてしっかり体感させる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            AudioServicesPlaySystemSound(SystemSoundID(4095))
        }
    }

    // MARK: - システム音量制御

    /// アラーム発動時にシステム音量を指定レベルに設定（0.0〜1.0）
    private func setSystemVolume(to level: Float) {
        #if os(iOS)
        let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }
        window.addSubview(volumeView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = level
            }
            volumeView.removeFromSuperview()
        }
        #endif
    }

    // MARK: - オーディオセッション設定

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // サイレントモードでも再生 + 他のアプリの音を止める
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("オーディオセッション設定エラー: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - フォールバックアラーム音

    /// カスタム音声ファイルがない場合でもバックグラウンド再生を維持できるフォールバック
    private func playGeneratedAlarm() {
        do {
            audioPlayer = try AVAudioPlayer(data: makeAlarmToneWAVData())
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.85
            audioPlayer?.prepareToPlay()
            isPlaying = audioPlayer?.play() == true
            if !isPlaying {
                print("合成アラーム音の再生開始に失敗しました")
                playSystemSoundFallback()
            }
        } catch {
            print("合成アラーム音の再生に失敗: \(error.localizedDescription)")
            playSystemSoundFallback()
        }
    }

    /// AVAudioPlayer が使えない場合の最終フォールバック
    private func playSystemSoundFallback() {
        AudioServicesPlaySystemSound(1005)
        isPlaying = true
        systemSoundTimer?.invalidate()
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else {
                self?.systemSoundTimer?.invalidate()
                return
            }
            AudioServicesPlaySystemSound(1005)
        }
        if let systemSoundTimer {
            RunLoop.main.add(systemSoundTimer, forMode: .common)
        }
    }

    /// 1秒の警告音WAVをメモリ上で生成する
    private func makeAlarmToneWAVData() -> Data {
        let sampleRate = 44_100
        let duration = 1.0
        let sampleCount = Int(Double(sampleRate) * duration)
        let channelCount = 1
        let bitsPerSample = 16
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let dataSize = sampleCount * blockAlign

        var data = Data()
        appendASCII("RIFF", to: &data)
        appendUInt32LE(UInt32(36 + dataSize), to: &data)
        appendASCII("WAVE", to: &data)
        appendASCII("fmt ", to: &data)
        appendUInt32LE(16, to: &data)
        appendUInt16LE(1, to: &data)
        appendUInt16LE(UInt16(channelCount), to: &data)
        appendUInt32LE(UInt32(sampleRate), to: &data)
        appendUInt32LE(UInt32(byteRate), to: &data)
        appendUInt16LE(UInt16(blockAlign), to: &data)
        appendUInt16LE(UInt16(bitsPerSample), to: &data)
        appendASCII("data", to: &data)
        appendUInt32LE(UInt32(dataSize), to: &data)

        for index in 0..<sampleCount {
            let phase = Double(index) / Double(sampleRate)
            let frequency = index < sampleCount / 2 ? 880.0 : 660.0
            let envelope = sin(.pi * Double(index) / Double(sampleCount))
            let sample = Int16(sin(2.0 * .pi * frequency * phase) * envelope * 28_000)
            appendUInt16LE(UInt16(bitPattern: sample), to: &data)
        }

        return data
    }

    private func appendASCII(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0x00ff))
        data.append(UInt8((value & 0xff00) >> 8))
    }

    private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0x000000ff))
        data.append(UInt8((value & 0x0000ff00) >> 8))
        data.append(UInt8((value & 0x00ff0000) >> 16))
        data.append(UInt8((value & 0xff000000) >> 24))
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    deinit {
        systemSoundTimer?.invalidate()
        vibrationTimer?.invalidate()
        audioPlayer?.stop()
        silencePlayer?.stop()
    }
}
