import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct TimesaverApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var scheduler = AlarmScheduler()
    @StateObject private var historyManager = SleepHistoryManager()
    @StateObject private var settingsStore = AlarmSettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scheduler)
                .environmentObject(historyManager)
                .environmentObject(settingsStore)
                .onAppear {
                    scheduler.historyManager = historyManager
                    scheduler.settingsStore = settingsStore
                    // アプリ起動時にFirestoreからデータを取得
                    historyManager.fetchFromFirestore()
                    Task {
                        await settingsStore.fetchFromFirestore()
                    }
                }
        }
    }
}
