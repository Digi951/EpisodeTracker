import Foundation
import SwiftData

@Model
final class Universe {
    var name: String
    var syncKey: String?
    var episodes: [Episode]

    init(
        name: String,
        syncKey: String? = nil,
        episodes: [Episode] = []
    ) {
        self.name = name
        self.syncKey = syncKey ?? Universe.makeSyncKey(name: name)
        self.episodes = episodes
    }
}

extension Universe {
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
