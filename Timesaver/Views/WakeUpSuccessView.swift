import SwiftUI

/// 起床成功画面
struct WakeUpSuccessView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @EnvironmentObject var themeStore: AppThemeStore
    @State private var showConfetti = false

    var body: some View {
        let theme = themeStore.selectedTheme

        VStack(spacing: 30) {
            Spacer()

            // 成功アイコン
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundColor(theme.morningAccent)
                .scaleEffect(showConfetti ? 1.2 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showConfetti)

            VStack(spacing: 12) {
                Text("おはよう！")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(theme.text)

                Text("あなたの勝利です")
                    .font(.title3)
                    .foregroundColor(theme.textDim)

                Text("全てのアラームを停止しました")
                    .font(.caption)
                    .foregroundColor(theme.textDim)
            }

            Spacer()

            // 新しいセッションへ
            if #available(iOS 26.0, *) {
                Button {
                    scheduler.reset()
                } label: {
                    Text("新しいアラームをセット")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .tint(theme.green)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button {
                    scheduler.reset()
                } label: {
                    Text("新しいアラームをセット")
                }
                .buttonStyle(MaterialBounceButtonStyle(baseColor: theme.green))
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .onAppear {
            showConfetti = true
            scheduler.brightnessManager.restoreBrightness()
        }
    }
}

#Preview {
    WakeUpSuccessView()
        .environmentObject(AlarmScheduler())
        .environmentObject(AppThemeStore())
}
