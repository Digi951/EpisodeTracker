import Foundation
import SwiftData

@Model
final class Universe {
    var id: UUID
    var name: String
    var syncKey: String?
    var episodeRelationships: [Episode]? = []

    init(
        id: UUID = UUID(),
        name: String,
        syncKey: String? = nil,
        episodes: [Episode] = []
    ) {
        self.id = id
        self.name = name
        self.syncKey = syncKey ?? Universe.makeSyncKey(name: name)
        self.episodeRelationships = episodes
    }
}

extension Universe {
    var episodes: [Episode] {
        get { episodeRelationships ?? [] }
        set { episodeRelationships = newValue }
    }

    static func makeSyncKey(name: String) -> String {
        "universe:\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
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
}
