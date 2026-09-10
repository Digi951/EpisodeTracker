import Foundation
import SwiftData

@Model
final class Universe {
    var id: UUID = UUID()
    var name: String = ""
    var syncKey: String?
    var coverImageName: String?
    var styleRaw: String = CatalogStyle.numbered.rawValue
    /// Identifier of the managed catalog source this collection is bound to, when
    /// the user activated it from "Reihen auswählen". `nil` for hand-made
    /// collections and for pre-V9 collections until the binding adoption fills it
    /// in on an unambiguous name match. Added in SchemaV9 (V1.18 Paket 3).
    var managedCatalogID: String?
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
