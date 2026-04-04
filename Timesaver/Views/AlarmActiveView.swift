import SwiftUI
import AVFoundation

/// アラーム発動中画面: Night/Morning共通。モードに応じてテキスト・色を切り替え
struct AlarmActiveView: View {
    let mode: GeminiService.VerificationMode
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var isFlashing = false

    private var accentColor: Color {
        mode == .night ? .indigo : .red
    }

    var body: some View {
        ZStack {
            // 背景: 点滅
            accentColor
                .opacity(isFlashing ? 0.8 : 0.3)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isFlashing)

            VStack(spacing: 40) {
                Spacer()

                // アラームアイコン
                Image(systemName: mode == .night ? "moon.fill" : "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isFlashing ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isFlashing)

                // メッセージ
                VStack(spacing: 8) {
                    Text(mode == .night ? "おやすみの時間です" : "起きて！！！")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)

                    Text(mode == .night ? "布団に入りましょう" : "アラームが鳴っています")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // ボタン — Night: "Went to bed" / Morning: "Woke up"
                Button {
                    if mode == .night {
                        scheduler.startNightMission()
                    } else {
                        scheduler.startMission()
                    }
                } label: {
                    Text(mode == .night ? "Went to bed" : "Woke up")
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
    AlarmActiveView(mode: .morning)
        .environmentObject(AlarmScheduler())
}
