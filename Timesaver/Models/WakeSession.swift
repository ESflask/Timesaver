import Foundation

/// 起床セッション: デッドライン時刻と状態を管理
struct WakeSession: Codable {
    var deadlineTime: Date
    var alarmStartTime: Date  // 第1バッチの開始時刻
    var isActive: Bool
    var alarmsFired: Int      // 発動済みアラーム数
    var totalAlarms: Int      // 1バッチあたりのアラーム数
    var scheduledBatches: Int // これまでに作成したバッチ数

    init(deadlineTime: Date, totalAlarms: Int = 30) {
        self.deadlineTime = deadlineTime
        self.alarmStartTime = deadlineTime.addingTimeInterval(-Double(totalAlarms) * 60)
        self.isActive = false
        self.alarmsFired = 0
        self.totalAlarms = totalAlarms
        self.scheduledBatches = 1  // 初回セット時に1バッチ目を作成済みとする
    }

    /// バッチNの開始時刻（0始まり: 0が第1バッチ）
    /// 間隔 = totalAlarms + 1 分（全アラーム発火後1分のバッファ）
    func batchStartTime(for batch: Int) -> Date {
        let intervalSeconds = Double(totalAlarms + 1) * 60
        return alarmStartTime.addingTimeInterval(Double(batch) * intervalSeconds)
    }

    /// 次のバッチ開始時刻
    var nextBatchStartTime: Date {
        batchStartTime(for: scheduledBatches)
    }
}
