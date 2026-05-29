import SwiftUI

/// Resolves the user's chosen accent color inside the widget process.
///
/// The main app mirrors the selected `AppAccentColor` raw value into the shared
/// App Group defaults so the widget extension (a separate process) can read it.
/// The case-to-color mapping deliberately mirrors `AppAccentColor.color` in the
/// app target, following the codebase's per-target duplication convention for
/// widget-shared types.
enum WidgetAccentColor {
    static let storageKey = "appAccentColor"
    static let appGroupIdentifier = "group.com.digi.episodetracker"

    /// The currently selected accent color, read from the shared App Group.
    static var current: Color {
        let rawValue = UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: storageKey)
        return color(for: rawValue)
    }

    static func color(for rawValue: String?) -> Color {
        switch rawValue {
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "teal": .teal
        case "green": .green
        case "red": .red
        case "amber": Color(red: 0.79, green: 0.53, blue: 0.23)
        default: .blue
        }
    }
}
