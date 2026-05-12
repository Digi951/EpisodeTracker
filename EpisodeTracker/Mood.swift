import Foundation
import SwiftData

@Model
final class Mood {
    var name: String
    var iconName: String?
    var episodes: [Episode]

    init(name: String, iconName: String? = nil, episodes: [Episode] = []) {
        self.name = name
        self.iconName = iconName
        self.episodes = episodes
    }
}

extension Mood {
    static let defaultSuggestions: [(name: String, icon: String)] = [
        ("Gruselig", "😱"),
        ("Spannend", "⚡"),
        ("Witzig", "😄"),
        ("Nachdenklich", "🧠"),
        ("Klassiker", "⭐"),
        ("Abenteuer", "🧭")
    ]

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func matches(_ other: Mood) -> Bool {
        id == other.id || normalizedName == other.normalizedName
    }
}
