import Foundation

/// 起床セッション: デッドライン時刻と状態を管理
struct WakeSession: Codable {
    var deadlineTime: Date
    var alarmStartTime: Date  // デッドラインの30分前
    var isActive: Bool
    var alarmsFired: Int      // 発動済みアラーム数
    var totalAlarms: Int      // 合計アラーム数（30回）

    init(deadlineTime: Date) {
        self.deadlineTime = deadlineTime
        self.alarmStartTime = deadlineTime.addingTimeInterval(-30 * 60)  // 30分前
        self.isActive = false
        self.alarmsFired = 0
        self.totalAlarms = 30
    }

    /// 次のアラーム時刻を計算
    func nextAlarmTime(after index: Int) -> Date? {
        guard index < totalAlarms else { return nil }
        return alarmStartTime.addingTimeInterval(TimeInterval(index * 60))  // 1分おき
    }
}
