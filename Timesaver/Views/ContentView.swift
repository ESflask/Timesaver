import SwiftUI

/// メイン画面: 状態に応じて適切な画面を表示
struct ContentView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        switch scheduler.currentState {
        case .idle:
            DeadlineSetupView()
        case .armed:
            ArmedView()
        case .ringing:
            AlarmActiveView()
        case .missionActive:
            MissionView()
        case .success:
            WakeUpSuccessView()
        }
    }
}

// MARK: - デッドライン設定画面

struct DeadlineSetupView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var deadlineTime = Date()
    @State private var showingSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // タイトル
                VStack(spacing: 8) {
                    Text("INFINITE WAKE")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.primary)

                    Text("二度寝、完封。")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // デッドライン時刻ピッカー
                VStack(spacing: 12) {
                    Text("デッドライン時刻")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("この時刻に遅刻は許されない")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $deadlineTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // 30分前からの説明
                VStack(spacing: 4) {
                    let startTime = deadlineTime.addingTimeInterval(-30 * 60)
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "HH:mm"

                    Text("\(formatter.string(from: startTime)) からアラーム開始")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("1分おき × 30回の波状攻撃")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // セットボタン
                Button {
                    // 今日or明日の該当時刻を計算
                    let targetDate = calculateTargetDate(from: deadlineTime)
                    scheduler.setDeadline(targetDate)
                } label: {
                    Text("アラームをセット")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)

                // セットアップ手順
                Button {
                    showingSetup = true
                } label: {
                    Label("初回セットアップ手順", systemImage: "gear")
                        .font(.footnote)
                }
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showingSetup) {
                SetupInstructionsView()
            }
        }
    }

    /// 選択された時刻を今日or明日の日付に変換
    private func calculateTargetDate(from time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var target = calendar.date(bySettingHour: timeComponents.hour ?? 7,
                                    minute: timeComponents.minute ?? 0,
                                    second: 0,
                                    of: now)!

        // アラーム開始（30分前）が現在時刻より前なら翌日に設定
        let alarmStart = target.addingTimeInterval(-30 * 60)
        if alarmStart <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }

        return target
    }
}

// MARK: - セットアップ手順画面

struct SetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(ShortcutManager.setupInstructions)
                    .font(.body)
                    .padding()
            }
            .navigationTitle("初回セットアップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - アラームセット済み画面（就寝中）

struct ArmedView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "moon.fill")
                .font(.system(size: 60))
                .foregroundColor(.indigo)

            Text("アラームセット完了")
                .font(.title2)
                .fontWeight(.bold)

            if let session = scheduler.session {
                VStack(spacing: 8) {
                    Text("デッドライン: \(timeFormatter.string(from: session.deadlineTime))")
                        .font(.title)
                        .fontWeight(.heavy)

                    Text("アラーム開始: \(timeFormatter.string(from: session.alarmStartTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("30回の波状攻撃が待機中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("iPhoneを充電器に繋いで\nおやすみなさい")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // キャンセルボタン
            Button {
                scheduler.reset()
            } label: {
                Text("キャンセル")
                    .foregroundColor(.red)
                    .padding()
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmScheduler())
}
