import Foundation

struct WidgetLibrarySnapshot: Codable {
    var generatedAt: Date
    var libraryTitle: String
    var universes: [String]
    var episodes: [WidgetEpisodeSnapshot]
}

struct WidgetEpisodeSnapshot: Codable, Hashable {
    var id: UUID
    var episodeNumber: Int
    var title: String
    var releaseYear: Int
    var universeName: String?
    var isListened: Bool
    var isBookmarked: Bool
    var kindRaw: String
    var rating: Int?
    var lastListenedAt: Date?
    var coverImageName: String?

    var isSpecial: Bool { kindRaw == "special" }

    init(
        id: UUID,
        episodeNumber: Int,
        title: String,
        releaseYear: Int,
        universeName: String? = nil,
        isListened: Bool,
        isBookmarked: Bool = false,
        kindRaw: String = "regular",
        rating: Int? = nil,
        lastListenedAt: Date? = nil,
        coverImageName: String? = nil
    ) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.title = title
        self.releaseYear = releaseYear
        self.universeName = universeName
        self.isListened = isListened
        self.isBookmarked = isBookmarked
        self.kindRaw = kindRaw
        self.rating = rating
        self.lastListenedAt = lastListenedAt
        self.coverImageName = coverImageName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        episodeNumber = try container.decode(Int.self, forKey: .episodeNumber)
        title = try container.decode(String.self, forKey: .title)
        releaseYear = try container.decode(Int.self, forKey: .releaseYear)
        universeName = try container.decodeIfPresent(String.self, forKey: .universeName)
        isListened = try container.decode(Bool.self, forKey: .isListened)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        kindRaw = try container.decodeIfPresent(String.self, forKey: .kindRaw) ?? "regular"
        rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        lastListenedAt = try container.decodeIfPresent(Date.self, forKey: .lastListenedAt)
        coverImageName = try container.decodeIfPresent(String.self, forKey: .coverImageName)
    }
}
