import Foundation
import UserNotifications

/// アラームスケジュール管理
/// アプリ内でアラームを管理し、起きましたボタンが押されるまで繰り返す
@MainActor
class AlarmScheduler: ObservableObject {
    @Published var session: WakeSession?
    @Published var currentState: AppState = .idle
    @Published var consecutiveErrors: Int = 0 // 通信エラーの連続回数

    let brightnessManager = ScreenBrightnessManager()
    let soundManager = AlarmSoundManager()
    var historyManager: SleepHistoryManager?
    weak var settingsStore: AlarmSettingsStore?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "currentWakeSession"
    private var alarmTimer: Timer?
    private var alarmFireTimer: Timer?

    enum AppState {
        case idle              // 待機中
        case armed             // 起床アラームセット済み（就寝中）
        case ringing           // 起床アラーム発動中
        case missionActive     // 起床ミッション実行中（洗面台認証）
        case fallbackMission   // オフライン救済ミッション（起床シェイク）
        case nightFallbackMission // オフライン救済ミッション（就寝シェイク）
        case success           // 起床成功
        case nightArmed        // 就寝アラームセット済み
        case nightRinging      // 就寝アラーム発動中
        case nightMission      // 就寝ミッション実行中（布団認証）
        case nightSuccess      // 就寝認証成功
    }

    init() {
        loadSession()
        requestNotificationPermission()
        setupTestNotificationObserver()
    }

    private func setupTestNotificationObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TestAlarmSound"), object: nil, queue: .main) { [weak self] notification in
            if let date = notification.object as? Date {
                self?.setAlarm(date)
            }
        }
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

        currentState = .armed

        // ループ監視タイマー開始
        startMonitoringTimer()

        if startTime <= Date() {
            triggerMorningAlarmIfNeeded()
        } else {
            scheduleMorningAlarmFireTimer(for: startTime)
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

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleMonitoringTimerTick()
            }
        }
        alarmTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleMonitoringTimerTick() {
        guard let session,
              currentState != .success,
              currentState != .missionActive,
              currentState != .nightArmed,
              currentState != .nightRinging,
              currentState != .nightMission,
              currentState != .nightSuccess else { return }

        let now = Date()

        // ringing 状態への遷移（アラーム開始時刻を過ぎたら）
        if currentState == .armed, now >= session.alarmStartTime {
            triggerMorningAlarmIfNeeded(now: now)
        }

        // ringing中は通知を補充し続ける（起きるまで無制限）
        if currentState == .ringing {
            scheduleBackupNotifications(from: now.addingTimeInterval(60))
        }
    }

    /// 起床アラームを予定時刻に発火させる単発タイマー
    private func scheduleMorningAlarmFireTimer(for startTime: Date) {
        alarmFireTimer?.invalidate()

        let interval = max(startTime.timeIntervalSinceNow, 0.1)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.triggerMorningAlarmIfNeeded()
            }
        }
        alarmFireTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// 起床アラームの状態と音声を同時に発火・復旧する
    private func triggerMorningAlarmIfNeeded(now: Date = Date()) {
        guard let session,
              session.isActive,
              now >= session.alarmStartTime,
              currentState == .armed || currentState == .ringing else { return }

        let shouldRecordFire = currentState != .ringing
        if shouldRecordFire {
            historyManager?.recordAlarmFired()
        }
        if !soundManager.isPlaying {
            soundManager.playAlarm()
        }
        brightnessManager.maximizeBrightness()
        currentState = .ringing
        scheduleBackupNotifications(from: now.addingTimeInterval(60))
    }

    /// アプリ復帰時に保存済み状態と実際の音声状態を同期する
    func refreshAlarmState() {
        let now = Date()

        if let session, session.isActive {
            if now >= session.alarmStartTime {
                if currentState == .armed {
                    triggerMorningAlarmIfNeeded(now: now)
                } else if currentState == .ringing, !soundManager.isPlaying {
                    soundManager.playAlarm()
                }
                if currentState == .ringing {
                    brightnessManager.maximizeBrightness()
                }
            } else if currentState == .armed {
                soundManager.startSilenceLoop()
                scheduleMorningAlarmFireTimer(for: session.alarmStartTime)
            }
        }

        if currentState == .nightRinging, !soundManager.isPlaying {
            soundManager.playAlarm()
        }
        if currentState == .nightRinging {
            brightnessManager.maximizeBrightness()
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
            triggerNightAlarmIfNeeded()
        } else {
            currentState = .nightArmed
            bedtimeTimer?.invalidate()
            let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.triggerNightAlarmIfNeeded()
                }
            }
            bedtimeTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// 就寝アラームの状態と音声を同時に発火・復旧する
    private func triggerNightAlarmIfNeeded() {
        let shouldRecordFire = currentState != .nightRinging
        if shouldRecordFire {
            historyManager?.recordAlarmFired()
        }
        if !soundManager.isPlaying {
            soundManager.playAlarm()
        }
        brightnessManager.maximizeBrightness()
        currentState = .nightRinging
    }

    // MARK: - ユーザーアクション

    /// 「Went to bed」→ 音を止めて振動に切り替え → 就寝ミッション開始
    func startNightMission() {
        consecutiveErrors = 0
        soundManager.stopAlarm()
        soundManager.startSilenceLoop()
        soundManager.startVibration()
        historyManager?.recordActionButton()
        currentState = .nightMission
    }

    /// 就寝ミッション完了 → 振動停止 → 就寝成功 → 自動モード時は起床アラームもセット
    func nightMissionCompleted() {
        soundManager.stopVibration()
        soundManager.stopSilenceLoop()
        brightnessManager.restoreBrightness()
        historyManager?.recordMissionCompleted()
        currentState = .nightSuccess
        // 就寝アラーム関連のみキャンセル
        bedtimeTimer?.invalidate()
        bedtimeTimer = nil
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["bedtime-alarm"])

        // 自動モード: 就寝成功後に起床アラームを自動セット
        scheduleAutoWakeIfNeeded()
    }

    /// 「Woke up」→ 音を止めて振動に切り替え → ミッション開始
    func startMission() {
        consecutiveErrors = 0
        soundManager.stopAlarm()
        soundManager.startSilenceLoop()
        soundManager.startVibration()
        historyManager?.recordActionButton()
        currentState = .missionActive
    }

    /// 通信エラーを報告
    func reportCommunicationError() {
        consecutiveErrors += 1
    }

    /// オフライン救済ミッション（シェイク）に切り替え
    func switchToFallbackMission(mode: GeminiService.VerificationMode) {
        if mode == .night {
            currentState = .nightFallbackMission
        } else {
            currentState = .fallbackMission
        }
        saveSession()
    }

    /// ミッション完了 → 振動停止・全アラーム解除 → 成功画面
    func missionCompleted() {
        soundManager.stopVibration()
        brightnessManager.restoreBrightness()
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
        alarmFireTimer?.invalidate()
        alarmFireTimer = nil
        soundManager.stopAlarm()
        soundManager.stopSilenceLoop()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// リセット（設定画面に戻る）
    func reset() {
        let previousState = currentState
        cancelAllAlarms()
        session = nil
        currentState = .idle
        clearSession()

        if previousState == .success, settingsStore?.settings.autoEnabled == true {
            scheduleAutoAlarms()
        }
    }

    // MARK: - 自動アラーム

    /// 自動設定の時刻から今日or明日のDateを計算して両方セット
    func scheduleAutoAlarms() {
        guard let settings = settingsStore?.settings, settings.autoEnabled else { return }
        guard let bedtime = settings.nextScheduledDate(for: .bedtime, after: Date()) else { return }
        setBedtimeAlarm(bedtime)
    }

    /// 就寝成功後に起床アラームを自動セット（自動モード時のみ）
    func scheduleAutoWakeIfNeeded() {
        guard let settings = settingsStore?.settings, settings.autoEnabled else { return }
        guard let wakeTime = settings.nextScheduledDate(for: .wake, after: Date()) else { return }

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
            soundManager.startSilenceLoop()
            startMonitoringTimer()
            // アプリ再起動時に通知を補充
            if now >= saved.alarmStartTime {
                soundManager.playAlarm()
                scheduleBackupNotifications(from: now.addingTimeInterval(60))
            } else {
                scheduleMorningAlarmFireTimer(for: saved.alarmStartTime)
            }
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
