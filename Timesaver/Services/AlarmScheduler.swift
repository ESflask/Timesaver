import Foundation
import UserNotifications

/// アラームスケジュール管理
/// アプリ内でアラームを管理し、起きましたボタンが押されるまで繰り返す
@MainActor
class AlarmScheduler: ObservableObject {
    @Published var session: WakeSession?
    @Published var currentState: AppState = .idle
    @Published var consecutiveErrors: Int = 0 // 通信エラーの連続回数
    @Published var isDebugMode: Bool = false  // デバッグ（アラーム試用）モード

    let brightnessManager = ScreenBrightnessManager()
    let soundManager = AlarmSoundManager()
    var historyManager: SleepHistoryManager?
    weak var settingsStore: AlarmSettingsStore? {
        didSet {
            setupSettingsCallback()
        }
    }
    private let notificationCenter = UNUserNotificationCenter.current()
    private let sessionKey = "currentWakeSession"
    /// 就寝アラームの目標時刻（onSilenceLoopTick で監視）
    private var pendingBedtime: Date?

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

    private func setupSettingsCallback() {
        settingsStore?.onSettingsChanged = { [weak self] in
            Task { @MainActor in
                self?.handleSettingsChange()
            }
        }
    }

    private func handleSettingsChange() {
        print("設定が更新されました。アラームを再確認します。")
        
        guard let settings = settingsStore?.settings, settings.autoEnabled else {
            // 自動モードがオフになった場合、稼働中のアラームがあれば解除
            if currentState == .armed || currentState == .nightArmed {
                cancelAllAlarms()
                currentState = .idle
                session = nil
                clearSession()
            }
            return
        }

        // 自動モードがオンの場合
        switch currentState {
        case .idle:
            // 待機中なら次のアラーム（通常は就寝）をセット
            scheduleAutoAlarms()
            
        case .armed:
            // 起床アラーム待ちの場合、最新の設定で起床時刻を更新
            if let wakeTime = settings.nextScheduledDate(for: .wake, after: Date()) {
                print("起床アラームを再設定: \(wakeTime)")
                setAlarm(wakeTime)
            }
            
        case .nightArmed:
            // 就寝アラーム待ちの場合、最新の設定で就寝時刻を更新
            if let bedtime = settings.nextScheduledDate(for: .bedtime, after: Date()) {
                print("就寝アラームを再設定: \(bedtime)")
                setBedtimeAlarm(bedtime)
            }
            
        default:
            // それ以外の状態（鳴動中など）は何もしない
            break
        }
    }

    private func setupTestNotificationObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TestAlarmSound"), object: nil, queue: .main) { [weak self] notification in
            if let date = notification.object as? Date {
                self?.isDebugMode = true
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

        // 無音ループ開始（バックグラウンド維持 + 毎秒の時刻チェック）
        setupSilenceLoopCallback()
        soundManager.startSilenceLoop()

        // 直近のバックアップ通知をスケジュール（最大64件 = iOSの上限）
        scheduleBackupNotifications(from: startTime)

        if startTime <= Date() {
            // 既に時刻を過ぎている場合は即発動
            triggerMorningAlarmIfNeeded()
        } else {
            currentState = .armed
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

    // MARK: - 無音ループコールバック（スリープ中でも動作する時刻チェック）

    /// 無音ファイル再生完了のたびに呼ばれる時刻チェック処理
    /// silence.wav（1秒）の再生完了 → コールバック → 再生再開 のループで
    /// スリープ中でもバックグラウンドで確実に動作する
    private func setupSilenceLoopCallback() {
        soundManager.onSilenceLoopTick = { [weak self] in
            self?.checkAlarmTime()
        }
    }

    /// 毎秒の時刻チェック: 起床・就寝アラームの発動判定
    private func checkAlarmTime() {
        let now = Date()

        // 起床アラーム: armed → ringing
        if currentState == .armed, let session = session, now >= session.alarmStartTime {
            triggerMorningAlarmIfNeeded(now: now)
        }

        // 就寝アラーム: nightArmed → nightRinging
        if currentState == .nightArmed, let bedtime = pendingBedtime, now >= bedtime {
            pendingBedtime = nil
            triggerNightAlarmIfNeeded()
        }

        // ringing中は通知を補充（60秒おきに制限）
        if currentState == .ringing, let session = session {
            let elapsed = now.timeIntervalSince(session.alarmStartTime)
            if Int(elapsed) % 60 == 0 {
                scheduleBackupNotifications(from: now.addingTimeInterval(60))
            }
        }
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
                setupSilenceLoopCallback()
                soundManager.startSilenceLoop()
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

        // 無音ループ開始（バックグラウンド維持 + 毎秒の時刻チェック）
        setupSilenceLoopCallback()
        soundManager.startSilenceLoop()

        if bedtime.timeIntervalSinceNow <= 0 {
            // 既に時刻を過ぎている場合は即発動
            triggerNightAlarmIfNeeded()
        } else {
            // pendingBedtime をセットし、checkAlarmTime() で監視
            pendingBedtime = bedtime
            currentState = .nightArmed
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
        pendingBedtime = nil
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

    /// デバッグ用: オフライン救済（シェイク200回）ミッションを直接起動
    /// アラーム発動・Gemini認証を飛ばしてシェイク画面のみテストする
    func startOfflineDebugMission() {
        isDebugMode = true
        currentState = .fallbackMission
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
        pendingBedtime = nil
        soundManager.onSilenceLoopTick = nil
        soundManager.stopAlarm()
        soundManager.stopSilenceLoop()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// リセット（設定画面に戻る）
    func reset() {
        let previousState = currentState
        isDebugMode = false
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
            // 無音ループのコールバックをセットアップ（アプリ再起動時）
            setupSilenceLoopCallback()
            soundManager.startSilenceLoop()
            // アプリ再起動時に通知を補充・アラーム音を再開
            if now >= saved.alarmStartTime {
                soundManager.playAlarm()
                scheduleBackupNotifications(from: now.addingTimeInterval(60))
            }
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
