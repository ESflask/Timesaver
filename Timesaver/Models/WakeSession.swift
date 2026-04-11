import Foundation

/// 起床セッション: アラーム開始時刻と状態を管理
struct WakeSession: Codable {
    var alarmStartTime: Date  // アラーム開始時刻（ユーザーが入力する「起きる時刻」）
    var isActive: Bool

    init(alarmStartTime: Date) {
        self.alarmStartTime = alarmStartTime
        self.isActive = false
    }
}
