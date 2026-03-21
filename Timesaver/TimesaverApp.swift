import SwiftUI

@main
struct TimesaverApp: App {
    @StateObject private var scheduler = AlarmScheduler()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scheduler)
        }
    }
}
