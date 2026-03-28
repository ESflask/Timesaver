import Foundation

/// 睡眠・起床の記録
struct SleepRecord: Codable, Identifiable {
    var id: UUID
    var date: Date              // 記録日
    var bedtime: Date?          // 就寝時刻
    var wakeUpTime: Date?       // 起床時刻（Woke upを押した時刻）
    var missionCompletedTime: Date?  // ミッション完了時刻

    /// 就寝から起床までの時間（秒）
    var sleepDuration: TimeInterval? {
        guard let bed = bedtime, let wake = wakeUpTime else { return nil }
        return wake.timeIntervalSince(bed)
    }

    /// 起床からミッション完了までの時間（秒）
    var wakeUpDuration: TimeInterval? {
        guard let wake = wakeUpTime, let done = missionCompletedTime else { return nil }
        return done.timeIntervalSince(wake)
    }

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = date
    }
}
