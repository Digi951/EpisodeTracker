import Foundation
import SwiftData

@Model
final class Mood {
    var id: UUID
    var name: String
    var iconName: String?
    var syncKey: String?
    var episodeRelationships: [Episode]? = []

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        syncKey: String? = nil,
        episodes: [Episode] = []
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.syncKey = syncKey ?? Mood.makeSyncKey(name: name)
        self.episodeRelationships = episodes
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

    var episodes: [Episode] {
        get { episodeRelationships ?? [] }
        set { episodeRelationships = newValue }
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
