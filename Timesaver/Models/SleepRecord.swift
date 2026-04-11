import Foundation

/// 睡眠・起床の記録
/// Night/Morning両モード対応、各アクションのタイムスタンプを保持
struct SleepRecord: Codable, Identifiable {
    var id: UUID
    var mode: RecordMode           // night or morning
    var alarmSetTime: Date         // アラームをセットした時刻
    var alarmFiredTime: Date?      // アラームが鳴り始めた時刻
    var actionButtonTime: Date?    // 「起きた」or「布団に入った」を押した時刻
    var missionCompletedTime: Date? // Gemini認証が通った時刻

    enum RecordMode: String, Codable {
        case night
        case morning
    }

    /// アラーム発動 → ボタン押下までの秒数
    var reactionSeconds: TimeInterval? {
        guard let fired = alarmFiredTime, let action = actionButtonTime else { return nil }
        return action.timeIntervalSince(fired)
    }

    /// ボタン押下 → ミッション完了までの秒数
    var missionSeconds: TimeInterval? {
        guard let action = actionButtonTime, let done = missionCompletedTime else { return nil }
        return done.timeIntervalSince(action)
    }

    /// アラーム発動 → ミッション完了までの総秒数
    var totalSeconds: TimeInterval? {
        guard let fired = alarmFiredTime, let done = missionCompletedTime else { return nil }
        return done.timeIntervalSince(fired)
    }

    init(mode: RecordMode, alarmSetTime: Date) {
        self.id = UUID()
        self.mode = mode
        self.alarmSetTime = alarmSetTime
    }
}
