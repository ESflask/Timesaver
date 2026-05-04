import SwiftUI

@MainActor
final class AppThemeStore: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "infiniteWakeTheme"

    init() {
        let savedValue = UserDefaults.standard.string(forKey: storageKey)
        selectedTheme = AppTheme(rawValue: savedValue ?? "") ?? .purple
    }

    func select(_ theme: AppTheme) {
        selectedTheme = theme
    }
}
