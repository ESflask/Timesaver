import SwiftUI

/// 設定画面: 自動モードの切り替えと同期状態を管理
struct SettingsView: View {
    @EnvironmentObject var settingsStore: AlarmSettingsStore
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("自動アラーム", isOn: Binding(
                        get: { settingsStore.settings.autoEnabled },
                        set: { newValue in
                            settingsStore.setAutoEnabled(newValue)
                        }
                    ).animation())

                    if !settingsStore.settings.autoEnabled {
                        Toggle("就寝アラーム終了後に起床を自動セット", isOn: Binding(
                            get: { settingsStore.settings.autoSetWakeAlarmAfterBedtime },
                            set: { newValue in
                                settingsStore.setAutoSetWakeAlarmAfterBedtime(newValue)
                            }
                        ))
                        .font(.subheadline)
                    }
                } header: {
                    Text("アラーム設定モード")
                } footer: {
                    if settingsStore.settings.autoEnabled {
                        Text("曜日ごとの時刻編集は Morning / Night タブで行います。Night タブから次回の自動就寝アラームをセットできます。")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("手動モードでは従来どおり、その場で時刻を選んでアラームをセットします。")
                            if settingsStore.settings.autoSetWakeAlarmAfterBedtime {
                                Text("※「自動セット」がONの場合、就寝ミッション成功時に、現在の曜日設定に基づいた起床アラームが自動的に予約されます。")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        Label("次回の起床", systemImage: "sun.max.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text(settingsStore.nextAlarmSummary(for: .wake))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("次回の就寝", systemImage: "moon.fill")
                            .foregroundColor(.indigo)
                        Spacer()
                        Text(settingsStore.nextAlarmSummary(for: .bedtime))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("現在の曜日設定")
                } footer: {
                    Text("曜日ごとの時刻を変更すると、自動的に Firebase と同期されます。")
                }

                if settingsStore.isSyncing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("同期中...")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if settingsStore.settings.autoEnabled {
                    Section {
                        VolumeGuideView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } header: {
                        Text("音量の確認")
                    }
                }

                Section {
                    if #available(iOS 26.0, *) {
                        Button {
                            settingsStore.testAlarmSound()
                        } label: {
                            Text("アラーム音を試用")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .tint(.orange)

                        Button {
                            scheduler.startOfflineDebugMission()
                        } label: {
                            Text("オフラインデバッグモード")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .tint(.purple)
                    } else {
                        Button {
                            settingsStore.testAlarmSound()
                        } label: {
                            Text("アラーム音を試用")
                        }
                        .buttonStyle(MaterialBounceButtonStyle(baseColor: .orange))

                        Button {
                            scheduler.startOfflineDebugMission()
                        } label: {
                            Text("オフラインデバッグモード")
                        }
                        .buttonStyle(MaterialBounceButtonStyle(baseColor: .purple))
                    }
                } header: {
                    Text("デバッグ・テスト")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("「アラーム音を試用」: 10秒後にアラーム音が鳴ります。")
                        Text("「オフラインデバッグモード」: シェイク200回タスクを直接起動し、オフライン救済フローを検証できます。")
                    }
                }
            }
            .navigationTitle("時間設定")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await settingsStore.fetchFromFirestore()
            }
        }
    }
}
