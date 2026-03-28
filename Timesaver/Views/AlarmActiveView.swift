import SwiftUI
import AVFoundation

/// アラーム発動中画面: 画面全体が赤く点滅し、音が鳴り、「Woke up」ボタンを表示
struct AlarmActiveView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var isFlashing = false

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

                    Text("アラームが鳴っています")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // "Woke up" ボタン — ガラス質感 → 音を止めて振動に切り替え
                Button {
                    scheduler.soundManager.stopAlarm()
                    scheduler.startMission()
                } label: {
                    Text("Woke up")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isFlashing = true
            scheduler.soundManager.playAlarm()
            scheduler.brightnessManager.maximizeBrightness()
        }
        .onDisappear {
            scheduler.soundManager.stopAlarm()
        }
    }
}

#Preview {
    AlarmActiveView()
        .environmentObject(AlarmScheduler())
}
