import SwiftUI

/// 設定画面: 自動モードの切り替えと同期状態を管理
struct SettingsView: View {
    @EnvironmentObject var settingsStore: AlarmSettingsStore
    @EnvironmentObject var scheduler: AlarmScheduler
    @EnvironmentObject var themeStore: AppThemeStore

    private var theme: AppTheme {
        themeStore.selectedTheme
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    SettingsPanel(theme: theme) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("表示")
                                .font(.largeTitle.weight(.bold))
                                .foregroundColor(.white)
                                .textCase(nil)

                            NavigationLink {
                                ColorThemeSettingsView()
                            } label: {
                                HStack(spacing: 12) {
                                    Label("カラーテーマ", systemImage: "paintpalette.fill")
                                        .foregroundColor(theme.accent)

                                    Spacer()

                                    Text(theme.displayName)
                                        .foregroundColor(theme.textDim)

                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(theme.textDim)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)

                            Text("Web版と同じ4つのテーマから選択できます。")
                                .font(.footnote)
                                .foregroundColor(theme.textDim)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Section {
                        VStack(spacing: 16) {
                            alarmModeSettings
                            currentWeeklySettings

                            if settingsStore.isSyncing {
                                syncingSettings
                            }

                            debugSettings
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    } header: {
                        TimeSettingsHeader(theme: theme)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(theme.background.ignoresSafeArea())
            .tint(theme.accent)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigation(theme)
            .task {
                await settingsStore.fetchFromFirestore()
            }
        }
    }

    private var alarmModeSettings: some View {
        SettingsPanel(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                Text("アラーム設定モード")
                    .font(.headline)
                    .foregroundColor(theme.text)

                Toggle("自動アラーム", isOn: Binding(
                    get: { settingsStore.settings.autoEnabled },
                    set: { newValue in
                        settingsStore.setAutoEnabled(newValue)
                    }
                ).animation())
                .tint(theme.accent)
                .foregroundColor(theme.text)

                if !settingsStore.settings.autoEnabled {
                    Toggle("就寝アラーム終了後に起床を自動セット", isOn: Binding(
                        get: { settingsStore.settings.autoSetWakeAlarmAfterBedtime },
                        set: { newValue in
                            settingsStore.setAutoSetWakeAlarmAfterBedtime(newValue)
                        }
                    ))
                    .font(.subheadline)
                    .tint(theme.accent)
                    .foregroundColor(theme.text)
                }

                if settingsStore.settings.autoEnabled {
                    Text("曜日ごとの時刻編集は Morning / Night タブで行います。Night タブから次回の自動就寝アラームをセットできます。")
                        .font(.footnote)
                        .foregroundColor(theme.textDim)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("手動モードでは従来どおり、その場で時刻を選んでアラームをセットします。")
                            .foregroundColor(theme.textDim)
                        if settingsStore.settings.autoSetWakeAlarmAfterBedtime {
                            Text("※「自動セット」がONの場合、就寝ミッション成功時に、現在の曜日設定に基づいた起床アラームが自動的に予約されます。")
                                .foregroundColor(theme.morningAccent)
                        }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private var currentWeeklySettings: some View {
        SettingsPanel(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                Text("現在の曜日設定")
                    .font(.headline)
                    .foregroundColor(theme.text)

                SettingsSummaryRow(
                    title: "次回の起床",
                    value: settingsStore.nextAlarmSummary(for: .wake),
                    systemImage: "sun.max.fill",
                    accentColor: theme.morningAccent,
                    theme: theme
                )

                Divider()
                    .overlay(theme.textDim.opacity(0.2))

                SettingsSummaryRow(
                    title: "次回の就寝",
                    value: settingsStore.nextAlarmSummary(for: .bedtime),
                    systemImage: "moon.fill",
                    accentColor: theme.nightAccent,
                    theme: theme
                )

                Text("曜日ごとの時刻を変更すると、自動的に Firebase と同期されます。")
                    .font(.footnote)
                    .foregroundColor(theme.textDim)
            }
        }
    }

    private var syncingSettings: some View {
        SettingsPanel(theme: theme) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(theme.accent)

                Text("同期中...")
                    .foregroundColor(theme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var debugSettings: some View {
        SettingsPanel(theme: theme) {
            VStack(alignment: .leading, spacing: 14) {
                Text("デバッグ・テスト")
                    .font(.headline)
                    .foregroundColor(theme.text)

                debugButtons

                VStack(alignment: .leading, spacing: 6) {
                    Text("「アラーム音を試用」: 10秒後にアラーム音が鳴ります。")
                    Text("「オフラインデバッグモード」: シェイク200回タスクを直接起動し、オフライン救済フローを検証できます。")
                }
                .font(.footnote)
                .foregroundColor(theme.textDim)
            }
        }
    }

    @ViewBuilder
    private var debugButtons: some View {
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
            .tint(theme.morningAccent)

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
            .tint(theme.accent)
        } else {
            Button {
                settingsStore.testAlarmSound()
            } label: {
                Text("アラーム音を試用")
            }
            .buttonStyle(MaterialBounceButtonStyle(baseColor: theme.morningAccent))

            Button {
                scheduler.startOfflineDebugMission()
            } label: {
                Text("オフラインデバッグモード")
            }
            .buttonStyle(MaterialBounceButtonStyle(baseColor: theme.accent, foregroundColor: theme.onAccent))
        }
    }
}

private struct TimeSettingsHeader: View {
    let theme: AppTheme

    var body: some View {
        Text("時間設定")
            .font(.largeTitle.weight(.bold))
            .foregroundColor(theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 0)
            .padding(.bottom, 8)
            .background(theme.background)
            .textCase(nil)
    }
}

private struct SettingsPanel<Content: View>: View {
    let theme: AppTheme
    private let content: Content

    init(theme: AppTheme, @ViewBuilder content: () -> Content) {
        self.theme = theme
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingsSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String
    let accentColor: Color
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .foregroundColor(accentColor)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.textDim)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ColorThemeSettingsView: View {
    @EnvironmentObject var themeStore: AppThemeStore

    private var currentTheme: AppTheme {
        themeStore.selectedTheme
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeOptionButton(
                        theme: theme,
                        currentTheme: currentTheme,
                        isSelected: theme == currentTheme
                    ) {
                        themeStore.select(theme)
                    }
                }
            }
            .padding(20)
        }
        .background(currentTheme.background.ignoresSafeArea())
        .navigationTitle("カラーテーマ")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigation(currentTheme)
    }
}

private struct ThemeOptionButton: View {
    let theme: AppTheme
    let currentTheme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private var description: String {
        switch theme {
        case .purple:
            return "Web版デフォルトに近い紫テーマ"
        case .white:
            return "明るい白テーマ"
        case .black:
            return "黒基調の高コントラストテーマ"
        case .tokyoNight:
            return "Web版Tokyo Nightに近い夜色テーマ"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(theme.displayName)
                            .font(.headline)
                            .foregroundColor(currentTheme.text)

                        if theme == .purple {
                            Text("デフォルト")
                                .font(.caption.weight(.bold))
                                .foregroundColor(currentTheme.onAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(currentTheme.accent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundColor(currentTheme.textDim)

                    HStack(spacing: 8) {
                        ForEach(Array(theme.swatches.enumerated()), id: \.offset) { _, color in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(color)
                                .frame(height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(currentTheme.text.opacity(0.14), lineWidth: 1)
                                )
                        }
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? currentTheme.accent : currentTheme.textDim)
            }
            .padding(16)
            .background(currentTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? currentTheme.accent : currentTheme.accent.opacity(0.16), lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
