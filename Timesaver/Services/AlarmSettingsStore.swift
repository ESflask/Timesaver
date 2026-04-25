import SwiftUI
import FirebaseFirestore

@MainActor
final class AlarmSettingsStore: ObservableObject {
    @Published var settings: WeeklyAlarmSettings
    @Published var isSyncing = false

    /// 設定が外部（Firestore）から更新された際のコールバック
    var onSettingsChanged: (() -> Void)?

    private let localSettingsKey = "weeklyAlarmSettingsData"
    private var listenerRegistration: ListenerRegistration?

    init() {
        if let localSettings = Self.loadLocalSettings(forKey: localSettingsKey) {
            settings = localSettings
        } else {
            settings = WeeklyAlarmSettings.fromFirestoreData(nil)
        }
        
        listenToFirestore()
    }

    deinit {
        listenerRegistration?.remove()
    }

    func listenToFirestore() {
        listenerRegistration?.remove()
        listenerRegistration = FirestoreService.shared.subscribeToSettings { [weak self] newSettings in
            Task { @MainActor in
                // ローカルと異なる場合のみ更新してコールバック
                if self?.settings != newSettings {
                    self?.settings = newSettings
                    self?.saveLocal()
                    self?.onSettingsChanged?()
                }
            }
        }
    }

    func fetchFromFirestore() async {
        isSyncing = true

        do {
            let fetched = try await FirestoreService.shared.fetchSettings()
            settings = fetched
            saveLocal()
            isSyncing = false
        } catch {
            print("設定の取得に失敗: \(error.localizedDescription)")
            isSyncing = false
        }
    }

    func setAutoEnabled(_ enabled: Bool) {
        settings.autoEnabled = enabled
        persistAndSync()
    }

    func setAutoSetWakeAlarmAfterBedtime(_ enabled: Bool) {
        settings.autoSetWakeAlarmAfterBedtime = enabled
        persistAndSync()
    }

    /// デバッグ用: 10秒後にアラームを鳴らす
    func testAlarmSound() {
        let testDate = Date().addingTimeInterval(10)
        // ContentView で scheduler が EnvironmentObject として渡されているので、
        // 実際のアラーム制御は AlarmScheduler 側で行う
        NotificationCenter.default.post(name: NSNotification.Name("TestAlarmSound"), object: testDate)
    }

    func updateWakeTime(for weekday: WeekdayKey, date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        settings.updateWakeTime(
            for: weekday,
            hour: components.hour ?? 7,
            minute: components.minute ?? 0
        )
        persistAndSync()
    }

    func updateBedtime(for weekday: WeekdayKey, date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        settings.updateBedtime(
            for: weekday,
            hour: components.hour ?? 23,
            minute: components.minute ?? 0
        )
        persistAndSync()
    }

    func toggleTomorrowSkip(kind: ScheduledAlarmKind) {
        let tomorrow = tomorrowDate()
        let current = settings.skipOverride(for: tomorrow)

        switch kind {
        case .wake:
            settings.setSkipOverride(for: tomorrow, wake: !current.wake)
        case .bedtime:
            settings.setSkipOverride(for: tomorrow, bedtime: !current.bedtime)
        }

        persistAndSync()
    }

    func toggleTomorrowSkipAll() {
        let tomorrow = tomorrowDate()
        let current = settings.skipOverride(for: tomorrow)
        let newValue = !(current.wake && current.bedtime)
        settings.setSkipOverride(for: tomorrow, wake: newValue, bedtime: newValue)
        persistAndSync()
    }

    func tomorrowSkipOverride() -> SkipOverride {
        settings.skipOverride(for: tomorrowDate())
    }

    func nextAlarmSummary(for kind: ScheduledAlarmKind, after referenceDate: Date = Date()) -> String {
        guard let date = settings.nextScheduledDate(for: kind, after: referenceDate) else {
            return "未設定"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) HH:mm"
        return formatter.string(from: date)
    }

    func formattedTime(for weekday: WeekdayKey, kind: ScheduledAlarmKind) -> String {
        let day = settings.daySchedule(for: weekday)
        let hour: Int
        let minute: Int

        switch kind {
        case .wake:
            hour = day.wakeHour
            minute = day.wakeMinute
        case .bedtime:
            hour = day.bedtimeHour
            minute = day.bedtimeMinute
        }

        return String(format: "%02d:%02d", hour, minute)
    }

    private func persistAndSync() {
        settings.normalize()
        saveLocal()
        syncToFirestore()
    }

    private func saveLocal() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: localSettingsKey)
    }

    private func syncToFirestore() {
        let settingsToSave = settings
        isSyncing = true

        Task {
            do {
                try await FirestoreService.shared.saveSettings(settingsToSave)
                await MainActor.run {
                    self.isSyncing = false
                }
            } catch {
                print("設定の同期に失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSyncing = false
                }
            }
        }
    }

    private func tomorrowDate() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private static func loadLocalSettings(forKey key: String) -> WeeklyAlarmSettings? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WeeklyAlarmSettings.self, from: data) else {
            return nil
        }

        return decoded.normalized()
    }
}
