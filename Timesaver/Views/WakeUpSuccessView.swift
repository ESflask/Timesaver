import SwiftUI

/// 起床成功画面
struct WakeUpSuccessView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // 成功アイコン
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                .scaleEffect(showConfetti ? 1.2 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showConfetti)

            VStack(spacing: 12) {
                Text("おはよう！")
                    .font(.system(size: 40, weight: .black, design: .rounded))

                Text("あなたの勝利です")
                    .font(.title3)
                    .foregroundColor(.secondary)

                if let session = scheduler.session {
                    Text("アラーム \(scheduler.alarmsFired)回目で起床成功")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }

            Spacer()

            // 新しいセッションへ
            Button {
                scheduler.reset()
            } label: {
                Text("新しいアラームをセット")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            showConfetti = true
            // 画面の明るさを元に戻す
            ScreenBrightnessManager().restoreBrightness()
        }
    }
}

#Preview {
    WakeUpSuccessView()
        .environmentObject(AlarmScheduler())
}
