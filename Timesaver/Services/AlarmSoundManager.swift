import AVFoundation
import MediaPlayer
import UIKit

/// アラーム音の再生・停止・振動切り替えを管理
class AlarmSoundManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var systemSoundTimer: Timer?
    @Published var isPlaying = false
    @Published var isVibrating = false
    @Published var isSilencePlaying = false

    // MARK: - 無音ループ再生（バックグラウンド維持用）

    /// 無音ファイルをループ再生してアプリのサスペンドを防ぐ
    func startSilenceLoop() {
        guard !isSilencePlaying else { return }
        configureAudioSession()

        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            print("silence.wav が見つかりません")
            return
        }

        do {
            silencePlayer = try AVAudioPlayer(contentsOf: url)
            silencePlayer?.numberOfLoops = -1  // 無限ループ
            // 音源自体が無音なので、プレイヤー音量は下げずに再生状態を維持する
            silencePlayer?.volume = 1.0
            silencePlayer?.prepareToPlay()
            isSilencePlaying = silencePlayer?.play() == true
            disableRemoteControls()
        } catch {
            print("無音ループ再生に失敗: \(error.localizedDescription)")
        }
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
        // ロック画面のNow Playingにタップを促す情報を表示
        updateNowPlayingForAlarm()

        if let url = alarmSoundURL() {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1  // 無限ループ
                audioPlayer?.volume = 0.8        // サイレントモードでも気づける音量
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
    func startVibration() {
        guard !isVibrating else { return }
        isVibrating = true
        triggerVibration()
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isVibrating else { return }
            self.triggerVibration()
        }
    }

    /// 振動を停止
    func stopVibration() {
        isVibrating = false
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    /// 1回の振動を発生させる
    private func triggerVibration() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        // 短い間隔で連続振動させてしっかり体感させる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.impactOccurred()
        }
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

    // MARK: - システムサウンド代替

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
