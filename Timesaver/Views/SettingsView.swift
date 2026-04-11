import SwiftUI

/// 設定画面: 手動/自動アラーム切り替え + 自動時の時刻設定
struct SettingsView: View {
    // 自動設定ON/OFF
    @AppStorage("autoAlarmEnabled") private var autoAlarmEnabled = false

    // 自動設定用の時刻（時・分をUserDefaultsに保存）
    @AppStorage("autoBedtimeHour") private var autoBedtimeHour = 23
    @AppStorage("autoBedtimeMinute") private var autoBedtimeMinute = 0
    @AppStorage("autoWakeHour") private var autoWakeHour = 7
    @AppStorage("autoWakeMinute") private var autoWakeMinute = 0

    // DatePicker用のローカル状態
    @State private var bedtimeDate: Date = Date()
    @State private var wakeDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - アラームモード選択
                Section {
                    Toggle("自動アラーム", isOn: $autoAlarmEnabled.animation())
                } header: {
                    Text("アラーム設定モード")
                } footer: {
                    if autoAlarmEnabled {
                        Text("毎日同じ時刻に自動でアラームがセットされます。Nightタブを開くだけで就寝→起床まで自動管理します。")
                    } else {
                        Text("Night・Morningタブから毎回手動でアラームをセットします。")
                    }
                }

                // MARK: - 自動設定の時刻
                if autoAlarmEnabled {
                    Section {
                        DatePicker("就寝時刻", selection: $bedtimeDate, displayedComponents: .hourAndMinute)
                            .onChange(of: bedtimeDate) {
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtimeDate)
                                autoBedtimeHour = comps.hour ?? 23
                                autoBedtimeMinute = comps.minute ?? 0
                            }
                    } header: {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.indigo)
                            Text("就寝")
                        }
                    } footer: {
                        Text("この時刻に就寝アラームが鳴ります")
                    }

                    Section {
                        DatePicker("起床時刻", selection: $wakeDate, displayedComponents: .hourAndMinute)
                            .onChange(of: wakeDate) {
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
                                autoWakeHour = comps.hour ?? 7
                                autoWakeMinute = comps.minute ?? 0
                            }
                    } header: {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.orange)
                            Text("起床")
                        }
                    } footer: {
                        Text("就寝認証クリア後、この時刻に起床アラームが自動セットされます")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 保存済みの時刻をDatePickerに反映
                let cal = Calendar.current
                bedtimeDate = cal.date(bySettingHour: autoBedtimeHour, minute: autoBedtimeMinute, second: 0, of: Date()) ?? Date()
                wakeDate = cal.date(bySettingHour: autoWakeHour, minute: autoWakeMinute, second: 0, of: Date()) ?? Date()
            }
        }
    }
}

#Preview {
    SettingsView()
}
