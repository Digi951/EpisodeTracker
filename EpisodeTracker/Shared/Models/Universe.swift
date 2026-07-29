import Foundation
import SwiftData

@Model
final class Universe {
    var id: UUID = UUID()
    var name: String = ""
    var syncKey: String?
    var coverImageName: String?
    var styleRaw: String = CatalogStyle.numbered.rawValue
    @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

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

    var style: CatalogStyle {
        get { CatalogStyle(rawValue: styleRaw) ?? .numbered }
        set { styleRaw = newValue.rawValue }
    }

    var isAnthology: Bool { style == .anthology }

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
