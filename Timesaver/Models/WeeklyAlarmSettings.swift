import Foundation

/// 自動アラームの対象
enum ScheduledAlarmKind: String, Codable {
    case wake
    case bedtime
}

/// 曜日キー
enum WeekdayKey: String, CaseIterable, Codable, Identifiable {
    case sun
    case mon
    case tue
    case wed
    case thu
    case fri
    case sat

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .sun: return "日"
        case .mon: return "月"
        case .tue: return "火"
        case .wed: return "水"
        case .thu: return "木"
        case .fri: return "金"
        case .sat: return "土"
        }
    }

    static func from(calendarWeekday: Int) -> WeekdayKey {
        switch calendarWeekday {
        case 1: return .sun
        case 2: return .mon
        case 3: return .tue
        case 4: return .wed
        case 5: return .thu
        case 6: return .fri
        default: return .sat
        }
    }
}

/// 曜日ごとの起床・就寝時刻
struct DaySchedule: Codable, Equatable {
    var wakeHour: Int
    var wakeMinute: Int
    var bedtimeHour: Int
    var bedtimeMinute: Int

    init(
        wakeHour: Int = 7,
        wakeMinute: Int = 0,
        bedtimeHour: Int = 23,
        bedtimeMinute: Int = 0
    ) {
        self.wakeHour = Self.clampHour(wakeHour)
        self.wakeMinute = Self.clampMinute(wakeMinute)
        self.bedtimeHour = Self.clampHour(bedtimeHour)
        self.bedtimeMinute = Self.clampMinute(bedtimeMinute)
    }

    mutating func normalize() {
        wakeHour = Self.clampHour(wakeHour)
        wakeMinute = Self.clampMinute(wakeMinute)
        bedtimeHour = Self.clampHour(bedtimeHour)
        bedtimeMinute = Self.clampMinute(bedtimeMinute)
    }

    private static func clampHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    private static func clampMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }
}

/// 1日だけ有効なスキップ設定
struct SkipOverride: Codable, Equatable {
    var wake: Bool
    var bedtime: Bool

    init(wake: Bool = false, bedtime: Bool = false) {
        self.wake = wake
        self.bedtime = bedtime
    }

    var isEmpty: Bool {
        !wake && !bedtime
    }
}

/// Web / iOS 共通の自動アラーム設定
struct WeeklyAlarmSettings: Codable, Equatable {
    var autoEnabled: Bool
    var weeklySchedule: [String: DaySchedule]
    var skipOverrides: [String: SkipOverride]
    /// 就寝アラーム終了後、起床アラームを自動設定するか（手動モード用）
    var autoSetWakeAlarmAfterBedtime: Bool

    init(
        autoEnabled: Bool = false,
        weeklySchedule: [String: DaySchedule] = WeeklyAlarmSettings.defaultWeeklySchedule(),
        skipOverrides: [String: SkipOverride] = [:],
        autoSetWakeAlarmAfterBedtime: Bool = false
    ) {
        self.autoEnabled = autoEnabled
        self.weeklySchedule = weeklySchedule
        self.skipOverrides = skipOverrides
        self.autoSetWakeAlarmAfterBedtime = autoSetWakeAlarmAfterBedtime
        normalize()
    }

    static var empty: WeeklyAlarmSettings {
        WeeklyAlarmSettings()
    }

    static func defaultWeeklySchedule(
        wakeHour: Int = 7,
        wakeMinute: Int = 0,
        bedtimeHour: Int = 23,
        bedtimeMinute: Int = 0
    ) -> [String: DaySchedule] {
        let schedule = DaySchedule(
            wakeHour: wakeHour,
            wakeMinute: wakeMinute,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute
        )

        return Dictionary(uniqueKeysWithValues: WeekdayKey.allCases.map { ($0.rawValue, schedule) })
    }

    mutating func normalize(referenceDate: Date = Date(), calendar: Calendar = .current) {
        var normalizedSchedule: [String: DaySchedule] = [:]
        let fallback = weeklySchedule.values.first ?? DaySchedule()

        for weekday in WeekdayKey.allCases {
            var day = weeklySchedule[weekday.rawValue] ?? fallback
            day.normalize()
            normalizedSchedule[weekday.rawValue] = day
        }

        weeklySchedule = normalizedSchedule

        var normalizedOverrides: [String: SkipOverride] = [:]
        let todayKey = Self.dateKey(for: referenceDate, calendar: calendar)

        for (key, value) in skipOverrides {
            guard !value.isEmpty, key >= todayKey else { continue }
            normalizedOverrides[key] = value
        }

        skipOverrides = normalizedOverrides
    }

    func normalized(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeeklyAlarmSettings {
        var copy = self
        copy.normalize(referenceDate: referenceDate, calendar: calendar)
        return copy
    }

    func daySchedule(for weekday: WeekdayKey) -> DaySchedule {
        weeklySchedule[weekday.rawValue] ?? DaySchedule()
    }

    mutating func updateWakeTime(for weekday: WeekdayKey, hour: Int, minute: Int) {
        var day = daySchedule(for: weekday)
        day.wakeHour = hour
        day.wakeMinute = minute
        day.normalize()
        weeklySchedule[weekday.rawValue] = day
    }

    mutating func updateBedtime(for weekday: WeekdayKey, hour: Int, minute: Int) {
        var day = daySchedule(for: weekday)
        day.bedtimeHour = hour
        day.bedtimeMinute = minute
        day.normalize()
        weeklySchedule[weekday.rawValue] = day
    }

    func skipOverride(for date: Date, calendar: Calendar = .current) -> SkipOverride {
        skipOverrides[Self.dateKey(for: date, calendar: calendar)] ?? SkipOverride()
    }

    mutating func setSkipOverride(for date: Date, wake: Bool? = nil, bedtime: Bool? = nil, calendar: Calendar = .current) {
        let key = Self.dateKey(for: date, calendar: calendar)
        var override = skipOverrides[key] ?? SkipOverride()

        if let wake {
            override.wake = wake
        }
        if let bedtime {
            override.bedtime = bedtime
        }

        if override.isEmpty {
            skipOverrides.removeValue(forKey: key)
        } else {
            skipOverrides[key] = override
        }
    }

    func isSkipped(_ kind: ScheduledAlarmKind, on date: Date, calendar: Calendar = .current) -> Bool {
        let override = skipOverride(for: date, calendar: calendar)
        switch kind {
        case .wake:
            return override.wake
        case .bedtime:
            return override.bedtime
        }
    }

    func nextScheduledDate(
        for kind: ScheduledAlarmKind,
        after referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let startOfReference = calendar.startOfDay(for: referenceDate)

        for dayOffset in 0..<14 {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfReference) else {
                continue
            }

            let weekday = WeekdayKey.from(calendarWeekday: calendar.component(.weekday, from: targetDay))
            let day = daySchedule(for: weekday)

            let candidate: Date
            switch kind {
            case .wake:
                candidate = calendar.date(bySettingHour: day.wakeHour, minute: day.wakeMinute, second: 0, of: targetDay) ?? targetDay
            case .bedtime:
                candidate = calendar.date(bySettingHour: day.bedtimeHour, minute: day.bedtimeMinute, second: 0, of: targetDay) ?? targetDay
            }

            guard candidate > referenceDate else { continue }
            guard !isSkipped(kind, on: targetDay, calendar: calendar) else { continue }
            return candidate
        }

        return nil
    }

    func asFirestoreData(referenceDate: Date = Date(), calendar: Calendar = .current) -> [String: Any] {
        let normalized = normalized(referenceDate: referenceDate, calendar: calendar)

        let scheduleData = normalized.weeklySchedule.mapValues { day in
            [
                "wake_hour": day.wakeHour,
                "wake_minute": day.wakeMinute,
                "bedtime_hour": day.bedtimeHour,
                "bedtime_minute": day.bedtimeMinute
            ]
        }

        let skipData = normalized.skipOverrides.mapValues { override in
            [
                "wake": override.wake,
                "bedtime": override.bedtime
            ]
        }

        return [
            "auto_enabled": normalized.autoEnabled,
            "weekly_schedule": scheduleData,
            "skip_overrides": skipData,
            "auto_set_wake_alarm_after_bedtime": normalized.autoSetWakeAlarmAfterBedtime
        ]
    }

    static func fromFirestoreData(_ data: [String: Any]?) -> WeeklyAlarmSettings {
        let rawData = data ?? [:]
        let autoEnabled = rawData["auto_enabled"] as? Bool ?? false
        let autoSetWakeAlarmAfterBedtime = rawData["auto_set_wake_alarm_after_bedtime"] as? Bool ?? false

        if let weeklyScheduleData = rawData["weekly_schedule"] as? [String: Any] {
            var weeklySchedule: [String: DaySchedule] = [:]

            for weekday in WeekdayKey.allCases {
                let day = weeklyScheduleData[weekday.rawValue] as? [String: Any] ?? [:]
                weeklySchedule[weekday.rawValue] = DaySchedule(
                    wakeHour: day["wake_hour"] as? Int ?? 7,
                    wakeMinute: day["wake_minute"] as? Int ?? 0,
                    bedtimeHour: day["bedtime_hour"] as? Int ?? 23,
                    bedtimeMinute: day["bedtime_minute"] as? Int ?? 0
                )
            }

            var skipOverrides: [String: SkipOverride] = [:]
            if let overridesData = rawData["skip_overrides"] as? [String: Any] {
                for (dateKey, rawOverride) in overridesData {
                    let overrideData = rawOverride as? [String: Any] ?? [:]
                    let override = SkipOverride(
                        wake: overrideData["wake"] as? Bool ?? false,
                        bedtime: overrideData["bedtime"] as? Bool ?? false
                    )
                    if !override.isEmpty {
                        skipOverrides[dateKey] = override
                    }
                }
            }

            return WeeklyAlarmSettings(
                autoEnabled: autoEnabled,
                weeklySchedule: weeklySchedule,
                skipOverrides: skipOverrides,
                autoSetWakeAlarmAfterBedtime: autoSetWakeAlarmAfterBedtime
            )
        }

        let defaults = UserDefaults.standard
        let legacyBedtimeHour = rawData["bedtime_hour"] as? Int ?? (defaults.object(forKey: "autoBedtimeHour") as? Int) ?? 23
        let legacyBedtimeMinute = rawData["bedtime_minute"] as? Int ?? (defaults.object(forKey: "autoBedtimeMinute") as? Int) ?? 0
        let legacyWakeHour = rawData["wake_hour"] as? Int ?? (defaults.object(forKey: "autoWakeHour") as? Int) ?? 7
        let legacyWakeMinute = rawData["wake_minute"] as? Int ?? (defaults.object(forKey: "autoWakeMinute") as? Int) ?? 0

        return WeeklyAlarmSettings(
            autoEnabled: autoEnabled,
            weeklySchedule: defaultWeeklySchedule(
                wakeHour: legacyWakeHour,
                wakeMinute: legacyWakeMinute,
                bedtimeHour: legacyBedtimeHour,
                bedtimeMinute: legacyBedtimeMinute
            ),
            autoSetWakeAlarmAfterBedtime: autoSetWakeAlarmAfterBedtime
        )
    }

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
