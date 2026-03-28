import SwiftUI

@main
struct TimesaverApp: App {
    @StateObject private var scheduler = AlarmScheduler()
    @StateObject private var historyManager = SleepHistoryManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scheduler)
                .environmentObject(historyManager)
                .onAppear {
                    scheduler.historyManager = historyManager
                }
        }
    }
}
