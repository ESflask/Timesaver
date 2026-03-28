import SwiftUI

/// メイン画面: 状態に応じて適切な画面を表示
struct ContentView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        switch scheduler.currentState {
        case .idle:
            MainTabView()
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

// MARK: - タブ切り替え画面

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NightAlarmView()
                .tabItem {
                    Image(systemName: "moon.fill")
                    Text("Night")
                }
                .tag(0)

            MorningAlarmView()
                .tabItem {
                    Image(systemName: "sun.max.fill")
                    Text("Morning")
                }
                .tag(1)
        }
    }
}

// MARK: - 就寝アラーム設定画面（Night）

struct NightAlarmView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var bedtime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // タイトル
                VStack(spacing: 8) {
                    Text("Night")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    Text("おやすみアラーム")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 就寝時刻ピッカー
                VStack(spacing: 12) {
                    Text("就寝時刻")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("この時刻にベッドに入る")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $bedtime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Spacer()

                // セットボタン
                Button {
                    let targetDate = calculateBedtime(from: bedtime)
                    scheduler.setBedtimeAlarm(targetDate)
                } label: {
                    Text("就寝アラームをセット")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
            }
        }
    }

    /// 選択された時刻を今日or明日の日付に変換
    private func calculateBedtime(from time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: time)

        var target = calendar.date(bySettingHour: components.hour ?? 23,
                                    minute: components.minute ?? 0,
                                    second: 0,
                                    of: now)!

        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }

        return target
    }
}

// MARK: - 起床アラーム設定画面（Morning）

struct MorningAlarmView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var deadlineTime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var alarmCount = 30
    @State private var showingAlarmCountPicker = false
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // タイトル
                VStack(spacing: 8) {
                    Text("Morning")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    Text("二度寝でも3度寝でも、諦めない")
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

                // アラーム開始時刻 + 回数設定
                VStack(spacing: 4) {
                    let startTime = deadlineTime.addingTimeInterval(-Double(alarmCount) * 60)
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "HH:mm"

                    Text("\(formatter.string(from: startTime)) からアラーム開始")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 4) {
                        Text("1分おき ×")
                        Button {
                            showingAlarmCountPicker = true
                        } label: {
                            HStack(spacing: 2) {
                                Text("\(alarmCount)回")
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .confirmationDialog("アラーム回数を選択", isPresented: $showingAlarmCountPicker) {
                            ForEach([5, 10, 15, 20, 25, 30], id: \.self) { count in
                                Button("\(count)回") { alarmCount = count }
                            }
                            Button("キャンセル", role: .cancel) {}
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // セットボタン
                Button {
                    let targetDate = calculateTargetDate(from: deadlineTime)
                    scheduler.setDeadline(targetDate, alarmCount: alarmCount)
                } label: {
                    Text("起床アラームをセット")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
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

        // アラーム開始（N分前）が現在時刻より前なら翌日に設定
        let alarmStart = target.addingTimeInterval(-Double(alarmCount) * 60)
        if alarmStart <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }

        return target
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

                    Text("\(session.totalAlarms)回分のアラームをセット済み")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // アラーム登録中の表示
            if scheduler.isScheduling {
                ProgressView("アラーム登録中...")
                    .padding()
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
