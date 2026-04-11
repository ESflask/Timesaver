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
    @AppStorage("autoAlarmEnabled") private var autoAlarmEnabled = false
    @State private var bedtime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    }()
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

                if autoAlarmEnabled {
                    // 自動モード: タブ表示時に自動でアラームセット
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 40))
                            .foregroundColor(.indigo)

                        Text("自動アラームを準備中...")
                            .font(.headline)

                        Text("設定タブで時刻を変更できます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        // Nightタブ表示時に自動でアラームをセット
                        scheduler.scheduleAutoAlarms()
                    }

                    Spacer()
                } else {
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

                    // セットボタン
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
    @AppStorage("autoAlarmEnabled") private var autoAlarmEnabled = false
    @State private var alarmTime: Date = {
        let cal = Calendar.current
        return cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }()

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

                if autoAlarmEnabled {
                    // 自動モード: 案内メッセージ
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)

                        Text("自動アラームが有効です")
                            .font(.headline)

                        Text("Nightタブを開くと自動でアラームがセットされ\n起床アラームも自動で管理されます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                } else {
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

                    // セットボタン
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

            Spacer()

            Text("そろそろ寝る準備を\nしておきましょう")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

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

            Button {
                scheduler.reset()
            } label: {
                Text("閉じる")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.indigo)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmScheduler())
}
