import Foundation
import SwiftData

@Model
final class Mood {
    var name: String
    var iconName: String?
    var syncKey: String?
    var episodes: [Episode]

    init(
        name: String,
        iconName: String? = nil,
        syncKey: String? = nil,
        episodes: [Episode] = []
    ) {
        self.name = name
        self.iconName = iconName
        self.syncKey = syncKey ?? Mood.makeSyncKey(name: name)
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

    static func makeSyncKey(name: String) -> String {
        "mood:\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    var resolvedSyncKey: String {
        let trimmed = syncKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? Self.makeSyncKey(name: name) : trimmed
    }

    func ensureSyncKey() {
        let trimmed = syncKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            syncKey = Self.makeSyncKey(name: name)
        }
    }

    func matches(_ other: Mood) -> Bool {
        id == other.id || resolvedSyncKey == other.resolvedSyncKey || normalizedName == other.normalizedName
    }
}
