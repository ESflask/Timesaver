import SwiftUI
import AVFoundation

/// アラーム発動中画面: 画面全体が赤く点滅し、「起きたボタン」を表示
struct AlarmActiveView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var isFlashing = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            // 背景: 赤く点滅
            Color.red
                .opacity(isFlashing ? 0.8 : 0.3)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isFlashing)

            VStack(spacing: 40) {
                Spacer()

                // アラームアイコン
                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isFlashing ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isFlashing)

                // アラーム情報
                VStack(spacing: 8) {
                    Text("起きて！！！")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(.white)

                    Text("アラーム \(scheduler.alarmsFired) / 30")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // 「起きた」ボタン → ミッションへ
                Button {
                    stopSound()
                    scheduler.startMission()
                } label: {
                    Text("起きた！ミッションに挑戦")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 24)

                Text("ミッションをクリアしないとアラームは止まりません")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            isFlashing = true
            playAlarmSound()
            // 画面の明るさを最大にする
            UIScreen.main.brightness = 1.0
        }
    }

    // MARK: - アラーム音再生

    private func playAlarmSound() {
        // システムサウンドでアラーム音を再生
        AudioServicesPlayAlertSound(SystemSoundID(1005))

        // ショートカット経由でも鳴らす
        ShortcutManager.triggerAlarmShortcut()
    }

    private func stopSound() {
        audioPlayer?.stop()
    }
}

#Preview {
    AlarmActiveView()
        .environmentObject(AlarmScheduler())
}
