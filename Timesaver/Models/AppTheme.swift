import SwiftUI

/// アプリ全体で使うカラーテーマ
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case purple
    case white
    case black
    case tokyoNight = "tokyo-night"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .purple:
            return "紫"
        case .white:
            return "白"
        case .black:
            return "黒"
        case .tokyoNight:
            return "Tokyo Night"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .white:
            return .light
        case .purple, .black, .tokyoNight:
            return .dark
        }
    }

    var background: Color {
        switch self {
        case .purple: return Color(hex: "#0f0f1a")
        case .white: return Color(hex: "#f6f7fb")
        case .black: return Color(hex: "#050505")
        case .tokyoNight: return Color(hex: "#1a1b26")
        }
    }

    var surface: Color {
        switch self {
        case .purple: return Color(hex: "#1a1a2e")
        case .white: return Color(hex: "#ffffff")
        case .black: return Color(hex: "#101010")
        case .tokyoNight: return Color(hex: "#24283b")
        }
    }

    var surface2: Color {
        switch self {
        case .purple: return Color(hex: "#242442")
        case .white: return Color(hex: "#eef1f6")
        case .black: return Color(hex: "#1c1c1c")
        case .tokyoNight: return Color(hex: "#2f3549")
        }
    }

    var accent: Color {
        switch self {
        case .purple: return Color(hex: "#6366f1")
        case .white: return Color(hex: "#2563eb")
        case .black: return Color(hex: "#f5f5f5")
        case .tokyoNight: return Color(hex: "#7aa2f7")
        }
    }

    var accentLight: Color {
        switch self {
        case .purple: return Color(hex: "#818cf8")
        case .white: return Color(hex: "#1d4ed8")
        case .black: return Color(hex: "#ffffff")
        case .tokyoNight: return Color(hex: "#bb9af7")
        }
    }

    var logoAccent: Color {
        switch self {
        case .purple: return Color(hex: "#a78bfa")
        case .white: return Color(hex: "#14b8a6")
        case .black: return Color(hex: "#a3a3a3")
        case .tokyoNight: return Color(hex: "#2ac3de")
        }
    }

    var onAccent: Color {
        switch self {
        case .black:
            return Color(hex: "#050505")
        case .tokyoNight:
            return Color(hex: "#111827")
        case .purple, .white:
            return .white
        }
    }

    var text: Color {
        switch self {
        case .purple: return Color(hex: "#e2e8f0")
        case .white: return Color(hex: "#172033")
        case .black: return Color(hex: "#f4f4f5")
        case .tokyoNight: return Color(hex: "#c0caf5")
        }
    }

    var textDim: Color {
        switch self {
        case .purple: return Color(hex: "#94a3b8")
        case .white: return Color(hex: "#64748b")
        case .black: return Color(hex: "#a1a1aa")
        case .tokyoNight: return Color(hex: "#9aa5ce")
        }
    }

    var green: Color {
        switch self {
        case .purple: return Color(hex: "#22c55e")
        case .white: return Color(hex: "#16a34a")
        case .black: return Color(hex: "#4ade80")
        case .tokyoNight: return Color(hex: "#9ece6a")
        }
    }

    var red: Color {
        switch self {
        case .purple: return Color(hex: "#ef4444")
        case .white: return Color(hex: "#dc2626")
        case .black: return Color(hex: "#f87171")
        case .tokyoNight: return Color(hex: "#f7768e")
        }
    }

    var orange: Color {
        switch self {
        case .purple: return Color(hex: "#f59e0b")
        case .white: return Color(hex: "#d97706")
        case .black: return Color(hex: "#fbbf24")
        case .tokyoNight: return Color(hex: "#e0af68")
        }
    }

    var morningAccent: Color { orange }
    var nightAccent: Color { accentLight }

    var swatches: [Color] {
        [background, surface, accent, text]
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 8:
            red = (value >> 24) & 0xff
            green = (value >> 16) & 0xff
            blue = (value >> 8) & 0xff
            alpha = value & 0xff
        default:
            red = (value >> 16) & 0xff
            green = (value >> 8) & 0xff
            blue = value & 0xff
            alpha = 0xff
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

private struct ThemedNavigationModifier: ViewModifier {
    let theme: AppTheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
    }
}

extension View {
    func themedNavigation(_ theme: AppTheme) -> some View {
        modifier(ThemedNavigationModifier(theme: theme))
    }
}
