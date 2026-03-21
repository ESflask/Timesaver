import SwiftUI

/// 覚醒ミッション選択・実行画面
struct MissionView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var selectedMission: MissionType?

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Text("覚醒ミッション")
                .font(.system(size: 32, weight: .black))

            Text("脳が起きていることを証明せよ")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let mission = selectedMission {
                switch mission {
                case .math:
                    MathMissionView {
                        scheduler.missionCompleted()
                    }
                case .shake:
                    ShakeMissionView {
                        scheduler.missionCompleted()
                    }
                }
            } else {
                // ミッション選択
                VStack(spacing: 16) {
                    MissionButton(
                        icon: "function",
                        title: "計算問題",
                        description: "3問正解せよ",
                        color: .blue
                    ) {
                        selectedMission = .math
                    }

                    MissionButton(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "シェイク",
                        description: "スマホを激しく振れ",
                        color: .orange
                    ) {
                        selectedMission = .shake
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }
}

// MARK: - ミッション選択ボタン

struct MissionButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)
        }
    }
}

#Preview {
    MissionView()
        .environmentObject(AlarmScheduler())
}
