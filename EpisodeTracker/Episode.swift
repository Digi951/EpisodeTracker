import Foundation
import SwiftData

@Model
final class Episode {
    var syncKey: String?
    var episodeNumber: Int
    var title: String
    var releaseYear: Int
    var personalNote: String?
    var isListened: Bool
    var rating: Int?
    var listenCount: Int
    var lastListenedAt: Date?
    @Relationship(inverse: \Universe.episodes) var universe: Universe?
    @Relationship(inverse: \Mood.episodes) var moods: [Mood]

    init(
        episodeNumber: Int,
        title: String,
        releaseYear: Int,
        syncKey: String? = nil,
        personalNote: String? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int = 0,
        lastListenedAt: Date? = nil,
        universe: Universe? = nil,
        moods: [Mood] = []
    ) {
        self.syncKey = syncKey ?? Episode.makeSyncKey(
            universeSyncKey: universe?.resolvedSyncKey,
            episodeNumber: episodeNumber
        )
        self.episodeNumber = episodeNumber
        self.title = title
        self.releaseYear = releaseYear
        self.personalNote = personalNote
        self.isListened = isListened
        self.rating = rating
        self.listenCount = listenCount
        self.lastListenedAt = lastListenedAt
        self.universe = universe
        self.moods = moods
    }
}

extension Episode {
    static func makeSyncKey(
        universeSyncKey: String?,
        episodeNumber: Int
    ) -> String {
        guard let universeSyncKey,
              !universeSyncKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "episode:pending:\(UUID().uuidString.lowercased())"
        }

        return "episode:\(universeSyncKey)#\(episodeNumber)"
    }

    var resolvedSyncKey: String {
        let trimmed = syncKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }

        return Self.makeSyncKey(
            universeSyncKey: universe?.resolvedSyncKey,
            episodeNumber: episodeNumber
        )
    }

    func refreshSyncKeyIfPossible() {
        if let universe {
            syncKey = Self.makeSyncKey(
                universeSyncKey: universe.resolvedSyncKey,
                episodeNumber: episodeNumber
            )
        } else {
            let trimmed = syncKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
            syncKey = Self.makeSyncKey(
                universeSyncKey: nil,
                episodeNumber: episodeNumber
            )
            }
        }
    }
}
