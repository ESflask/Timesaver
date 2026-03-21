import Foundation
import UserNotifications
import AVFoundation

/// 30回のアラームスケジュールを管理
class AlarmScheduler: ObservableObject {
    @Published var session: WakeSession?
    @Published var currentState: AppState = .idle
    @Published var alarmsFired: Int = 0

    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "currentWakeSession"

    enum AppState {
        case idle           // 待機中（デッドライン未設定）
        case armed          // アラームセット済み（就寝中）
        case ringing        // アラーム発動中
        case missionActive  // ミッション実行中
        case success        // 起床成功
    }

    init() {
        loadSession()
        requestNotificationPermission()
    }

    // MARK: - 通知権限

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            if let error = error {
                print("通知権限エラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - セッション管理

    /// デッドライン時刻を設定し、30回のアラームをスケジュール
    func setDeadline(_ deadline: Date) {
        let session = WakeSession(deadlineTime: deadline)
        self.session = session
        self.currentState = .armed
        scheduleAllAlarms(for: session)
        saveSession()
    }

    /// 全アラームをスケジュール（30回、1分おき）
    private func scheduleAllAlarms(for session: WakeSession) {
        // 既存の通知をクリア
        cancelAllAlarms()

        for i in 0..<session.totalAlarms {
            guard let alarmTime = session.nextAlarmTime(after: i) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "⏰ 起きて！"
            content.body = "アラーム \(i + 1)/\(session.totalAlarms) — アプリを開いてミッションをクリアしてください"
            content.sound = UNNotificationSound.defaultCritical
            content.interruptionLevel = .critical
            content.categoryIdentifier = "WAKE_ALARM"

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alarmTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "alarm-\(i)",
                content: content,
                trigger: trigger
            )

            notificationCenter.add(request)
        }
    }

    /// アラーム発動時の処理
    func onAlarmTriggered() {
        alarmsFired += 1
        currentState = .ringing
        // ショートカット経由でシステムアラーム音を鳴らす
        ShortcutManager.triggerAlarmShortcut()
    }

    /// 「起きたボタン」→ ミッション開始
    func startMission() {
        currentState = .missionActive
    }

    /// ミッション完了 → 全アラーム解除
    func missionCompleted() {
        currentState = .success
        cancelAllAlarms()
        session?.isActive = false
        saveSession()
    }

    /// 全アラームをキャンセル
    func cancelAllAlarms() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// リセット（新しいセッションへ）
    func reset() {
        cancelAllAlarms()
        session = nil
        currentState = .idle
        alarmsFired = 0
        clearSession()
    }

    // MARK: - 永続化

    private func saveSession() {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let saved = try? JSONDecoder().decode(WakeSession.self, from: data) else { return }
        session = saved
        if saved.isActive {
            currentState = .armed
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
