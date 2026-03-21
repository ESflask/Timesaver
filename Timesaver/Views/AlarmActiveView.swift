import SwiftUI
import AVFoundation

/// アラーム発動中画面: 画面全体が赤く点滅し、「起きたボタン」を表示
/// 純正時計アプリのアラームが鳴っている状態で、ユーザーにミッションへ誘導する
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

                    Text("純正時計アプリでアラームが鳴っています")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // 「起きた」ボタン → ミッションへ
                Button {
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

                Text("ミッションをクリアしないと\n残りのアラームは止まりません")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            isFlashing = true
            scheduler.brightnessManager.maximizeBrightness()
        }
    }
}

#Preview {
    AlarmActiveView()
        .environmentObject(AlarmScheduler())
}
