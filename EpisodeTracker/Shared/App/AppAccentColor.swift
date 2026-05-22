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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blau"
        case .indigo: "Indigo"
        case .purple: "Lila"
        case .teal: "Teal"
        case .green: "Grün"
        case .red: "Rot"
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
        }
    }

    static func resolved(from rawValue: String) -> AppAccentColor {
        AppAccentColor(rawValue: rawValue) ?? defaultValue
    }
}
