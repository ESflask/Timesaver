import SwiftUI

// MARK: - Materialボタンスタイル（押下で白く光り、バウンスするエフェクト）

struct MaterialBounceButtonStyle: ButtonStyle {
    var baseColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(baseColor)
                    // 押下時に白くフラッシュするオーバーレイ
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(configuration.isPressed ? 0.35 : 0))
                }
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// メイン画面: 状態に応じて適切な画面を表示
struct ContentView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        switch scheduler.currentState {
        case .idle:
            MainTabView()
        // Morning
        case .armed:
            ArmedView()
        case .ringing:
            AlarmActiveView(mode: .morning)
        case .missionActive:
            VerificationChatView(mode: .morning)
        case .fallbackMission:
            ShakeMissionView {
                scheduler.missionCompleted()
            }
        case .nightFallbackMission:
            ShakeMissionView {
                scheduler.nightMissionCompleted()
            }
        case .success:
            WakeUpSuccessView()
        // Night
        case .nightArmed:
            NightArmedView()
        case .nightRinging:
            AlarmActiveView(mode: .night)
        case .nightMission:
            VerificationChatView(mode: .night)
        case .nightSuccess:
            NightSuccessView()
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

            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(3)
        }
    }
}

// MARK: - 就寝アラーム設定画面（Night）

struct NightAlarmView: View {
    @EnvironmentObject var scheduler: AlarmScheduler
    @EnvironmentObject var settingsStore: AlarmSettingsStore
    @State private var bedtime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var editingDay: WeekdayKey?
    @State private var editingDate = Date()

    private var autoAlarmEnabled: Bool {
        settingsStore.settings.autoEnabled
    }

    var body: some View {
        NavigationStack {
            Group {
            if autoAlarmEnabled {
                ScrollView {
                    VStack(spacing: 20) {
                        screenSubtitle("曜日ごとの就寝時刻を管理")

                        AutoAlarmSummaryCard(
                            title: "次回の就寝アラーム",
                            value: settingsStore.nextAlarmSummary(for: .bedtime),
                            accentColor: .indigo,
                            systemImage: "moon.zzz.fill"
                        )

                        WeekdayScheduleGrid(
                            title: "曜日ごとの就寝時刻",
                            kind: .bedtime,
                            accentColor: .indigo
                        ) { weekday in
                            editingDay = weekday
                            editingDate = dateForTime(
                                hour: settingsStore.settings.daySchedule(for: weekday).bedtimeHour,
                                minute: settingsStore.settings.daySchedule(for: weekday).bedtimeMinute
                            )
                        }

                        TomorrowSkipSection(
                            accentColor: .indigo,
                            skipOverride: settingsStore.tomorrowSkipOverride(),
                            onToggleWake: {
                                settingsStore.toggleTomorrowSkip(kind: .wake)
                            },
                            onToggleBedtime: {
                                settingsStore.toggleTomorrowSkip(kind: .bedtime)
                            },
                            onToggleAll: {
                                settingsStore.toggleTomorrowSkipAll()
                            }
                        )

                        if settingsStore.isSyncing {
                            syncStatusRow()
                        }

                        if #available(iOS 26.0, *) {
                            Button {
                                scheduler.scheduleAutoAlarms()
                            } label: {
                                Text("次の自動就寝アラームをセット")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.glass)
                            .tint(.indigo)
                        } else {
                            Button {
                                scheduler.scheduleAutoAlarms()
                            } label: {
                                Text("次の自動就寝アラームをセット")
                            }
                            .buttonStyle(MaterialBounceButtonStyle(baseColor: .indigo))
                        }

                        Text("曜日をタップすると、その曜日だけ就寝時刻を変更できます。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .sheet(item: $editingDay) { weekday in
                    DayTimeEditorSheet(
                        weekday: weekday,
                        kind: .bedtime,
                        accentColor: .indigo,
                        initialDate: editingDate
                    ) { selectedDate in
                        settingsStore.updateBedtime(for: weekday, date: selectedDate)
                    }
                }
            } else {
                VStack(spacing: 30) {
                    Spacer()

                    screenSubtitle("おやすみアラーム")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)

                    Spacer()

                    // 手動モード: 従来のピッカー + セットボタン
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

                    if #available(iOS 26.0, *) {
                        Button {
                            let targetDate = calculateBedtime(from: bedtime)
                            scheduler.setBedtimeAlarm(targetDate)
                        } label: {
                            Text("就寝アラームをセット")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.glass)
                        .tint(.blue)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    } else {
                        Button {
                            let targetDate = calculateBedtime(from: bedtime)
                            scheduler.setBedtimeAlarm(targetDate)
                        } label: {
                            Text("就寝アラームをセット")
                        }
                        .buttonStyle(MaterialBounceButtonStyle(baseColor: .blue))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            }
            .navigationTitle("Night")
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
    @EnvironmentObject var settingsStore: AlarmSettingsStore
    @State private var alarmTime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var editingDay: WeekdayKey?
    @State private var editingDate = Date()

    private var autoAlarmEnabled: Bool {
        settingsStore.settings.autoEnabled
    }

    var body: some View {
        NavigationStack {
            Group {
            if autoAlarmEnabled {
                ScrollView {
                    VStack(spacing: 20) {
                        screenSubtitle("曜日ごとの起床時刻を管理")

                        AutoAlarmSummaryCard(
                            title: "次回の起床アラーム",
                            value: settingsStore.nextAlarmSummary(for: .wake),
                            accentColor: .orange,
                            systemImage: "sun.max.fill"
                        )

                        WeekdayScheduleGrid(
                            title: "曜日ごとの起床時刻",
                            kind: .wake,
                            accentColor: .orange
                        ) { weekday in
                            editingDay = weekday
                            editingDate = dateForTime(
                                hour: settingsStore.settings.daySchedule(for: weekday).wakeHour,
                                minute: settingsStore.settings.daySchedule(for: weekday).wakeMinute
                            )
                        }

                        TomorrowSkipSection(
                            accentColor: .orange,
                            skipOverride: settingsStore.tomorrowSkipOverride(),
                            onToggleWake: {
                                settingsStore.toggleTomorrowSkip(kind: .wake)
                            },
                            onToggleBedtime: {
                                settingsStore.toggleTomorrowSkip(kind: .bedtime)
                            },
                            onToggleAll: {
                                settingsStore.toggleTomorrowSkipAll()
                            }
                        )

                        if settingsStore.isSyncing {
                            syncStatusRow()
                        }

                        Text("Night側で就寝認証が完了すると、この曜日設定をもとに次回の起床アラームが決まります。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .sheet(item: $editingDay) { weekday in
                    DayTimeEditorSheet(
                        weekday: weekday,
                        kind: .wake,
                        accentColor: .orange,
                        initialDate: editingDate
                    ) { selectedDate in
                        settingsStore.updateWakeTime(for: weekday, date: selectedDate)
                    }
                }
            } else {
                VStack(spacing: 30) {
                    Spacer()

                    screenSubtitle("二度寝でも3度寝でも、諦めない")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)

                    Spacer()

                    // 手動モード: 従来のピッカー + セットボタン
                    VStack(spacing: 12) {
                        Text("アラーム開始時刻")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("「起きた」を押すまで1分おきに鳴り続けます")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    Spacer()

                    if #available(iOS 26.0, *) {
                        Button {
                            let targetDate = calculateTargetDate(from: alarmTime)
                            scheduler.setAlarm(targetDate)
                        } label: {
                            Text("起床アラームをセット")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.glass)
                        .tint(.blue)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    } else {
                        Button {
                            let targetDate = calculateTargetDate(from: alarmTime)
                            scheduler.setAlarm(targetDate)
                        } label: {
                            Text("起床アラームをセット")
                        }
                        .buttonStyle(MaterialBounceButtonStyle(baseColor: .blue))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            }
            .navigationTitle("Morning")
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

        // アラーム開始時刻が現在時刻より前なら翌日に設定
        if target <= now {
            target = calendar.date(byAdding: .day, value: 1, to: target)!
        }

        return target
    }
}

// MARK: - 自動アラーム UI

/// ナビバーのタイトル直下に表示するサブタイトル。タイトル本体は `.navigationTitle` に委譲しているため、ここではサブテキストのみを描画する。
@ViewBuilder
private func screenSubtitle(_ subtitle: String) -> some View {
    Text(subtitle)
        .font(.title3)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
}

private func dateForTime(hour: Int, minute: Int) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
}

private func syncStatusRow() -> some View {
    HStack(spacing: 10) {
        ProgressView()
        Text("Firebase に同期中...")
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
}

struct AutoAlarmSummaryCard: View {
    let title: String
    let value: String
    let accentColor: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(accentColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WeekdayScheduleGrid: View {
    @EnvironmentObject var settingsStore: AlarmSettingsStore

    let title: String
    let kind: ScheduledAlarmKind
    let accentColor: Color
    let onTap: (WeekdayKey) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(WeekdayKey.allCases) { weekday in
                    Button {
                        onTap(weekday)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(weekday.shortLabel)曜日")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(settingsStore.formattedTime(for: weekday, kind: kind))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(accentColor.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TomorrowSkipSection: View {
    let accentColor: Color
    let skipOverride: SkipOverride
    let onToggleWake: () -> Void
    let onToggleBedtime: () -> Void
    let onToggleAll: () -> Void

    private var tomorrowLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("明日のスキップ")
                .font(.headline)

            Text("\(tomorrowLabel) の起床・就寝だけを一時的に無効化できます")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                SkipToggleButton(
                    title: "明朝をスキップ",
                    isActive: skipOverride.wake,
                    accentColor: accentColor,
                    action: onToggleWake
                )
                SkipToggleButton(
                    title: "明夜をスキップ",
                    isActive: skipOverride.bedtime,
                    accentColor: accentColor,
                    action: onToggleBedtime
                )
            }

            SkipToggleButton(
                title: "明日を全部スキップ",
                isActive: skipOverride.wake && skipOverride.bedtime,
                accentColor: accentColor,
                action: onToggleAll
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SkipToggleButton: View {
    let title: String
    let isActive: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundColor(isActive ? .white : accentColor)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? accentColor : accentColor.opacity(0.12))
        )
    }
}

struct DayTimeEditorSheet: View {
    let weekday: WeekdayKey
    let kind: ScheduledAlarmKind
    let accentColor: Color
    let initialDate: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(
        weekday: WeekdayKey,
        kind: ScheduledAlarmKind,
        accentColor: Color,
        initialDate: Date,
        onSave: @escaping (Date) -> Void
    ) {
        self.weekday = weekday
        self.kind = kind
        self.accentColor = accentColor
        self.initialDate = initialDate
        self.onSave = onSave
        _selectedDate = State(initialValue: initialDate)
    }

    private var title: String {
        switch kind {
        case .wake:
            return "\(weekday.shortLabel)曜日の起床時刻"
        case .bedtime:
            return "\(weekday.shortLabel)曜日の就寝時刻"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Text("保存すると Firebase に同期されます")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(selectedDate)
                        dismiss()
                    }
                    .tint(accentColor)
                }
            }
        }
    }
}

// MARK: - 音量ガイド（共通コンポーネント）

/// 音量を最低1段階にするよう促すガイド表示
struct VolumeGuideView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("volume_guide")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 4)

            Text("上の画像のように、iPhoneの音量ボタンを\n無音状態から一回だけ押した状態にしてください")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
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
                    Text("アラーム開始: \(timeFormatter.string(from: session.alarmStartTime))")
                        .font(.title)
                        .fontWeight(.heavy)

                    Text("「起きた」を押すまで1分おきに鳴り続けます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VolumeGuideView()

            Spacer()

            Text("iPhoneを充電器に繋いで\nおやすみなさい")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // キャンセルボタン
            if #available(iOS 26.0, *) {
                Button {
                    scheduler.reset()
                } label: {
                    Text("キャンセル")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .tint(.red)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button {
                    scheduler.reset()
                } label: {
                    Text("キャンセル")
                }
                .buttonStyle(MaterialBounceButtonStyle(baseColor: .red))
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 就寝アラームセット済み画面

struct NightArmedView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.indigo)

            Text("就寝アラームセット完了")
                .font(.title2)
                .fontWeight(.bold)

            Text("時間になったらお知らせします")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VolumeGuideView()

            Spacer()

            Text("そろそろ寝る準備を\nしておきましょう")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if #available(iOS 26.0, *) {
                Button {
                    scheduler.reset()
                } label: {
                    Text("キャンセル")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .tint(.red)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button {
                    scheduler.reset()
                } label: {
                    Text("キャンセル")
                }
                .buttonStyle(MaterialBounceButtonStyle(baseColor: .red))
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 就寝認証成功画面

struct NightSuccessView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundColor(.indigo)

            Text("おやすみなさい")
                .font(.system(size: 36, weight: .black, design: .rounded))

            Text("ぐっすり眠ってください")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            if #available(iOS 26.0, *) {
                Button {
                    scheduler.reset()
                } label: {
                    Text("閉じる")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .tint(.indigo)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button {
                    scheduler.reset()
                } label: {
                    Text("閉じる")
                }
                .buttonStyle(MaterialBounceButtonStyle(baseColor: .indigo))
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            scheduler.brightnessManager.restoreBrightness()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmScheduler())
        .environmentObject(SleepHistoryManager())
        .environmentObject(AlarmSettingsStore())
}
