import Foundation
import SwiftData

@Model
final class Mood {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String?
    var syncKey: String?
    @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

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
        (String(localized: "Mood.Gruselig", defaultValue: "Gruselig"), "😱"),
        (String(localized: "Mood.Spannend", defaultValue: "Spannend"), "⚡"),
        (String(localized: "Mood.Witzig", defaultValue: "Witzig"), "😄"),
        (String(localized: "Mood.Nachdenklich", defaultValue: "Nachdenklich"), "🧠"),
        (String(localized: "Mood.Klassiker", defaultValue: "Klassiker"), "⭐"),
        (String(localized: "Mood.Abenteuer", defaultValue: "Abenteuer"), "🧭")
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

    /// Ordering used to pick the representative when several `Mood` records share
    /// a canonical identity (same `normalizedName`) — e.g. duplicates introduced
    /// by sync. Returns `true` when `lhs` should win over `rhs`.
    static func isPreferredAsCanonical(_ lhs: Mood, over rhs: Mood) -> Bool {
        if lhs.episodes.count != rhs.episodes.count {
            return lhs.episodes.count > rhs.episodes.count
        }

        let lhsHasIcon = lhs.iconName?.isEmpty == false
        let rhsHasIcon = rhs.iconName?.isEmpty == false
        if lhsHasIcon != rhsHasIcon {
            return lhsHasIcon
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
