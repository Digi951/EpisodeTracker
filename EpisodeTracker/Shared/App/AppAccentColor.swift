import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable {
    static let storageKey = "appAccentColor"
    static let defaultValue = AppAccentColor.blue

    case blue
    case indigo
    case purple
    case teal
    case green
    case red
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blau"
        case .indigo: "Indigo"
        case .purple: "Lila"
        case .teal: "Teal"
        case .green: "Grün"
        case .red: "Rot"
        case .amber: "Bernstein"
        }
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .teal: .teal
        case .green: .green
        case .red: .red
        case .amber: Color(red: 0.79, green: 0.53, blue: 0.23)
        }
    }

    static func resolved(from rawValue: String) -> AppAccentColor {
        AppAccentColor(rawValue: rawValue) ?? defaultValue
    }
}

extension AppAccentColor {
    static let appGroupIdentifier = "group.com.digi.episodetracker"

    /// Mirrors the selected accent color into the shared App Group defaults so the
    /// widget extension can read it (the widget runs in a separate process and
    /// cannot see the app's standard `@AppStorage`).
    static func mirrorToAppGroup(rawValue: String) {
        UserDefaults(suiteName: appGroupIdentifier)?.set(rawValue, forKey: storageKey)
    }
}
