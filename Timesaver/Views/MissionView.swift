import SwiftUI

/// 覚醒ミッション画面: シェイクミッションを直接表示
struct MissionView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("覚醒ミッション")
                .font(.system(size: 32, weight: .black))

            Text("脳が起きていることを証明せよ")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            ShakeMissionView {
                scheduler.missionCompleted()
            }

            Spacer()
        }
    }
}

#Preview {
    MissionView()
        .environmentObject(AlarmScheduler())
}
