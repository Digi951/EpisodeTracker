import Foundation
import SwiftData

@Model
final class Episode {
    var id: UUID = UUID()
    var syncKey: String?
    var episodeNumber: Int = 0
    var title: String = ""
    var releaseYear: Int = 0
    var personalNote: String?
    var isListened: Bool = false
    var rating: Int?
    var listenCount: Int = 0
    var lastListenedAt: Date?
    var streamingURL: String?
    var coverImageName: String?
    var coverUpdatedAt: Date?
    var moodsUpdatedAt: Date?
    var isFavorite: Bool = false
    var isBookmarked: Bool = false
    var isHidden: Bool = false
    var ratingUpdatedAt: Date?
    var noteUpdatedAt: Date?
    var favoriteUpdatedAt: Date?
    var bookmarkedUpdatedAt: Date?
    var hiddenUpdatedAt: Date?
    var streamingURLUpdatedAt: Date?
    var listenStatusUpdatedAt: Date?
    var kindRaw: String = EpisodeKind.regular.rawValue
    var catalogSlug: String?
    var specialUpdatedAt: Date?
    @Relationship(inverse: \Universe.episodeRelationships) var universe: Universe?
    @Relationship(originalName: "moods", inverse: \Mood.episodeRelationships) var moodRelationships: [Mood]? = []

    init(
        id: UUID = UUID(),
        episodeNumber: Int,
        title: String,
        releaseYear: Int,
        syncKey: String? = nil,
        personalNote: String? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int = 0,
        lastListenedAt: Date? = nil,
        isFavorite: Bool = false,
        isBookmarked: Bool = false,
        isHidden: Bool = false,
        universe: Universe? = nil,
        moods: [Mood] = []
    ) {
        self.id = id
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
        self.isFavorite = isFavorite
        self.isBookmarked = isBookmarked
        self.isHidden = isHidden
        self.universe = universe
        self.moodRelationships = moods
    }
}

extension Episode {
    var moods: [Mood] {
        get { moodRelationships ?? [] }
        set { moodRelationships = newValue }
    }

    var kind: EpisodeKind {
        get { EpisodeKind(rawValue: kindRaw) ?? .regular }
        set { kindRaw = newValue.rawValue }
    }

    var isSpecial: Bool { kind == .special }

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
