import AVFoundation
import MediaPlayer
import UIKit

/// アラーム音の再生・停止・振動切り替えを管理
class AlarmSoundManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var silencePlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
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
            silencePlayer?.volume = 0.0        // 完全無音
            silencePlayer?.play()
            isSilencePlaying = true
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

        // リモートコマンドのハンドラを解除
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
    }

    // MARK: - 音声再生

    /// アラーム音を適度な音量でループ再生
    func playAlarm() {
        // オーディオセッションを設定（サイレントモードでも鳴るように）
        configureAudioSession()
        // ロック画面のNow Playingにタップを促す情報を表示
        updateNowPlayingForAlarm()

        guard let url = Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") else {
            // バンドルに音声ファイルがない場合はシステムサウンドで代替
            playSystemSound()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1  // 無限ループ
            audioPlayer?.volume = 0.7        // 適度な音量
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("アラーム音の再生に失敗: \(error.localizedDescription)")
            playSystemSound()
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

    /// カスタム音声ファイルがない場合のフォールバック
    private func playSystemSound() {
        // システムのアラーム音を使用（1005 = 短いアラート音）
        AudioServicesPlaySystemSound(1005)
        // 繰り返し再生のためタイマーで呼び出し
        isPlaying = true
        scheduleSystemSoundLoop()
    }

    private var systemSoundTimer: Timer?

    private func scheduleSystemSoundLoop() {
        systemSoundTimer?.invalidate()
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else {
                self?.systemSoundTimer?.invalidate()
                return
            }
            AudioServicesPlaySystemSound(1005)
        }
    }

    deinit {
        systemSoundTimer?.invalidate()
        vibrationTimer?.invalidate()
        audioPlayer?.stop()
        silencePlayer?.stop()
    }
}
