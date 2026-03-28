import Foundation
import UserNotifications

/// アラームスケジュール管理
/// アプリ内でアラームを管理し、起きましたボタンが押されるまで繰り返す
class AlarmScheduler: ObservableObject {
    @Published var session: WakeSession?
    @Published var currentState: AppState = .idle
    @Published var alarmsFired: Int = 0
    @Published var isScheduling: Bool = false

    let brightnessManager = ScreenBrightnessManager()
    let soundManager = AlarmSoundManager()
    var historyManager: SleepHistoryManager?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "currentWakeSession"
    private var alarmTimer: Timer?

    enum AppState {
        case idle           // 待機中（デッドライン未設定）
        case armed          // アラームセット済み（就寝中）
        case ringing        // アラーム発動中（起きましたボタン表示）
        case missionActive  // ミッション実行中
        case success        // 起床成功
    }

    init() {
        loadSession()
        requestNotificationPermission()
    }

    // MARK: - 通知権限

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { _, error in
            if let error = error {
                print("通知権限エラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - セッション管理

    /// デッドライン時刻を設定し、第1バッチのアラームを作成してループ監視を開始
    func setDeadline(_ deadline: Date, alarmCount: Int = 30) {
        var session = WakeSession(deadlineTime: deadline, totalAlarms: alarmCount)
        session.isActive = true
        self.session = session
        saveSession()

        // 就寝記録を開始
        historyManager?.recordBedtime(Date())

        // 第1バッチ作成
        scheduleAlarmBatch(startTime: session.alarmStartTime, count: session.totalAlarms, batchIndex: 0)

        // ループ監視タイマー開始
        startMonitoringTimer()

        DispatchQueue.main.async {
            self.currentState = .armed
        }
    }

    /// 指定開始時刻からN回分のアラームをスケジュール
    private func scheduleAlarmBatch(startTime: Date, count: Int, batchIndex: Int) {
        isScheduling = true

        // ローカル通知でアラームをスケジュール
        addBackupNotifications(startTime: startTime, count: count, batchIndex: batchIndex)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isScheduling = false
        }
    }

    /// バックアップ用ローカル通知を追加（バッチごとにIDを分けて既存通知を上書きしない）
    private func addBackupNotifications(startTime: Date, count: Int, batchIndex: Int) {
        for i in 0..<count {
            let alarmTime = startTime.addingTimeInterval(TimeInterval(i * 60))
            let content = UNMutableNotificationContent()
            content.title = "起きて！"
            content.body = "アラーム \(i + 1)/\(count) — アプリを開いてミッションをクリア"
            content.sound = UNNotificationSound.defaultCritical
            content.interruptionLevel = .critical
            content.categoryIdentifier = "WAKE_ALARM"

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "backup-alarm-\(batchIndex)-\(i)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }

    // MARK: - ループ監視タイマー

    /// 60秒ごとに状態をチェックし、必要に応じて次のバッチを作成
    private func startMonitoringTimer() {
        alarmTimer?.invalidate()

        alarmTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self,
                  var session = self.session,
                  self.currentState != .success,
                  self.currentState != .missionActive else { return }

            let now = Date()

            // ringing 状態への遷移（初回アラーム開始時刻を過ぎたら）
            if self.currentState == .armed, now >= session.alarmStartTime {
                DispatchQueue.main.async {
                    self.currentState = .ringing
                }
            }

            // 次バッチ作成チェック: 現在バッチのN+1分後になったら次バッチを作成
            if now >= session.nextBatchStartTime {
                let nextBatchStart = session.nextBatchStartTime
                let batchIndex = session.scheduledBatches

                session.scheduledBatches += 1
                self.session = session
                self.saveSession()

                DispatchQueue.main.async {
                    self.scheduleAlarmBatch(
                        startTime: nextBatchStart,
                        count: session.totalAlarms,
                        batchIndex: batchIndex
                    )
                }
            }
        }
    }

    // MARK: - 就寝アラーム

    /// 就寝時刻にアラームを1回セット
    func setBedtimeAlarm(_ bedtime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "おやすみの時間です"
        content.body = "ベッドに入りましょう"
        content.sound = UNNotificationSound.default
        content.interruptionLevel = .timeSensitive

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: bedtime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "bedtime-alarm", content: content, trigger: trigger)
        notificationCenter.add(request)
    }

    // MARK: - ユーザーアクション

    /// 「Woke up」→ 音を止めて振動に切り替え → ミッション開始
    func startMission() {
        soundManager.stopAlarm()
        soundManager.startVibration()
        historyManager?.recordWakeUp()
        currentState = .missionActive
    }

    /// ミッション完了 → 振動停止・全アラーム解除 → 成功画面
    func missionCompleted() {
        soundManager.stopVibration()
        historyManager?.recordMissionCompleted()
        currentState = .success
        cancelAllAlarms()
        session?.isActive = false
        saveSession()
    }

    /// 全アラームをキャンセル
    func cancelAllAlarms() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// リセット（設定画面に戻る）
    func reset() {
        cancelAllAlarms()
        session = nil
        currentState = .idle
        alarmsFired = 0
        isScheduling = false
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
            currentState = saved.alarmStartTime <= Date() ? .ringing : .armed
            startMonitoringTimer()
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
