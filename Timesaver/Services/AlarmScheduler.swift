import Foundation
import UserNotifications

/// アラームスケジュール管理
/// アプリ内でアラームを管理し、起きましたボタンが押されるまで繰り返す
class AlarmScheduler: ObservableObject {
    @Published var session: WakeSession?
    @Published var currentState: AppState = .idle

    let brightnessManager = ScreenBrightnessManager()
    let soundManager = AlarmSoundManager()
    var historyManager: SleepHistoryManager?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "currentWakeSession"
    private var alarmTimer: Timer?

    enum AppState {
        case idle              // 待機中
        case armed             // 起床アラームセット済み（就寝中）
        case ringing           // 起床アラーム発動中
        case missionActive     // 起床ミッション実行中（洗面台認証）
        case success           // 起床成功
        case nightArmed        // 就寝アラームセット済み
        case nightRinging      // 就寝アラーム発動中
        case nightMission      // 就寝ミッション実行中（布団認証）
        case nightSuccess      // 就寝認証成功
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

    /// アラーム開始時刻を設定し、無制限アラームを開始
    func setAlarm(_ startTime: Date) {
        var session = WakeSession(alarmStartTime: startTime)
        session.isActive = true
        self.session = session
        saveSession()

        // レコード開始
        historyManager?.startMorningRecord(alarmTime: startTime)

        // 無音ループ開始（バックグラウンド維持）
        soundManager.startSilenceLoop()

        // 直近のバックアップ通知をスケジュール（最大64件 = iOSの上限）
        scheduleBackupNotifications(from: startTime)

        // ループ監視タイマー開始
        startMonitoringTimer()

        DispatchQueue.main.async {
            self.currentState = .armed
        }
    }

    /// バックアップ用ローカル通知を1分おきにスケジュール（最大64件）
    private func scheduleBackupNotifications(from startTime: Date) {
        // 既存の起床アラーム通知を削除
        notificationCenter.removePendingNotificationRequests(withIdentifiers:
            (0..<64).map { "wake-alarm-\($0)" })

        let now = Date()
        let calendar = Calendar.current
        for i in 0..<64 {
            let alarmTime = startTime.addingTimeInterval(TimeInterval(i * 60))
            guard alarmTime > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "起きて！"
            content.body = "アプリを開いてミッションをクリア"
            content.sound = UNNotificationSound.defaultCritical
            content.interruptionLevel = .critical
            content.categoryIdentifier = "WAKE_ALARM"

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alarmTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "wake-alarm-\(i)", content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }

    // MARK: - ループ監視タイマー

    /// 60秒ごとに状態をチェックし、アラーム発動・通知補充を行う
    private func startMonitoringTimer() {
        alarmTimer?.invalidate()

        alarmTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self,
                  let session = self.session,
                  self.currentState != .success,
                  self.currentState != .missionActive,
                  self.currentState != .nightArmed,
                  self.currentState != .nightRinging,
                  self.currentState != .nightMission,
                  self.currentState != .nightSuccess else { return }

            let now = Date()

            // ringing 状態への遷移（アラーム開始時刻を過ぎたら）
            if self.currentState == .armed, now >= session.alarmStartTime {
                DispatchQueue.main.async {
                    self.historyManager?.recordAlarmFired()
                    self.currentState = .ringing
                }
            }

            // ringing中は通知を補充し続ける（起きるまで無制限）
            if self.currentState == .ringing {
                self.scheduleBackupNotifications(from: now.addingTimeInterval(60))
            }
        }
    }

    // MARK: - 就寝アラーム

    private var bedtimeTimer: Timer?

    /// 就寝時刻にアラームをセットし、時刻到来でnightRinging状態に遷移
    func setBedtimeAlarm(_ bedtime: Date) {
        // レコード開始
        historyManager?.startNightRecord(alarmTime: bedtime)

        // バックアップ通知
        let content = UNMutableNotificationContent()
        content.title = "おやすみの時間です"
        content.body = "アプリを開いて布団認証をしてください"
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: bedtime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "bedtime-alarm", content: content, trigger: trigger)
        notificationCenter.add(request)

        // 無音ループ開始（バックグラウンド維持）
        soundManager.startSilenceLoop()

        // アプリ内タイマーで状態遷移
        let interval = bedtime.timeIntervalSinceNow
        if interval <= 0 {
            // 既に時刻を過ぎている場合は即発動
            historyManager?.recordAlarmFired()
            currentState = .nightRinging
        } else {
            currentState = .nightArmed
            bedtimeTimer?.invalidate()
            bedtimeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.historyManager?.recordAlarmFired()
                    self?.currentState = .nightRinging
                }
            }
        }
    }

    /// 「Went to bed」→ 音を止めて振動に切り替え → 就寝ミッション開始
    func startNightMission() {
        soundManager.stopAlarm()
        soundManager.startVibration()
        historyManager?.recordActionButton()
        currentState = .nightMission
    }

    /// 就寝ミッション完了 → 振動停止 → 就寝成功 → 自動モード時は起床アラームもセット
    func nightMissionCompleted() {
        soundManager.stopVibration()
        soundManager.stopSilenceLoop()
        historyManager?.recordMissionCompleted()
        currentState = .nightSuccess
        // 就寝アラーム関連のみキャンセル
        bedtimeTimer?.invalidate()
        bedtimeTimer = nil
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["bedtime-alarm"])

        // 自動モード: 就寝成功後に起床アラームを自動セット
        scheduleAutoWakeIfNeeded()
    }

    // MARK: - ユーザーアクション

    /// 「Woke up」→ 音を止めて振動に切り替え → ミッション開始
    func startMission() {
        soundManager.stopAlarm()
        soundManager.startVibration()
        historyManager?.recordActionButton()
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
        soundManager.stopSilenceLoop()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// リセット（設定画面に戻る）
    func reset() {
        cancelAllAlarms()
        session = nil
        currentState = .idle
        clearSession()
    }

    // MARK: - 自動アラーム

    /// 自動設定の時刻から今日or明日のDateを計算して両方セット
    func scheduleAutoAlarms() {
        let cal = Calendar.current
        let now = Date()

        let bedHour = UserDefaults.standard.integer(forKey: "autoBedtimeHour")
        let bedMin  = UserDefaults.standard.integer(forKey: "autoBedtimeMinute")
        let wakeHour = UserDefaults.standard.integer(forKey: "autoWakeHour")
        let wakeMin  = UserDefaults.standard.integer(forKey: "autoWakeMinute")

        // 就寝アラーム: 今日の時刻が過ぎていたら明日
        var bedtime = cal.date(bySettingHour: bedHour, minute: bedMin, second: 0, of: now)!
        if bedtime <= now {
            bedtime = cal.date(byAdding: .day, value: 1, to: bedtime)!
        }

        // 起床アラーム: 就寝より後になるように調整
        var wakeTime = cal.date(bySettingHour: wakeHour, minute: wakeMin, second: 0, of: now)!
        if wakeTime <= now {
            wakeTime = cal.date(byAdding: .day, value: 1, to: wakeTime)!
        }
        // 起床が就寝より前なら翌日に
        if wakeTime <= bedtime {
            wakeTime = cal.date(byAdding: .day, value: 1, to: wakeTime)!
        }

        // まず就寝アラームをセット
        setBedtimeAlarm(bedtime)

        // 起床アラームは就寝成功後にセットするため保存しておく
        UserDefaults.standard.set(wakeTime.timeIntervalSince1970, forKey: "pendingAutoWakeTime")
    }

    /// 就寝成功後に起床アラームを自動セット（自動モード時のみ）
    func scheduleAutoWakeIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "autoAlarmEnabled"),
              let timestamp = UserDefaults.standard.object(forKey: "pendingAutoWakeTime") as? Double else { return }

        let wakeTime = Date(timeIntervalSince1970: timestamp)
        UserDefaults.standard.removeObject(forKey: "pendingAutoWakeTime")

        // 少し待ってからセット（就寝成功画面を表示する余裕）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.setAlarm(wakeTime)
        }
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
            let now = Date()
            currentState = now >= saved.alarmStartTime ? .ringing : .armed
            startMonitoringTimer()
            // アプリ再起動時に通知を補充
            if now >= saved.alarmStartTime {
                scheduleBackupNotifications(from: now.addingTimeInterval(60))
            }
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
