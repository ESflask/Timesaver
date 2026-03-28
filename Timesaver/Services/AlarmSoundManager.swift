import AVFoundation
import UIKit

/// アラーム音の再生・停止・振動切り替えを管理
class AlarmSoundManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    @Published var isPlaying = false
    @Published var isVibrating = false

    // MARK: - 音声再生

    /// アラーム音を適度な音量でループ再生
    func playAlarm() {
        // オーディオセッションを設定（サイレントモードでも鳴るように）
        configureAudioSession()

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
    }
}
