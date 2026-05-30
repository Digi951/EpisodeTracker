import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }

    @Model
    final class Episode {
        var episodeNumber: Int = 0
        var title: String = ""
        var releaseYear: Int = 0
        var personalNote: String?
        var isListened: Bool = false
        var rating: Int?
        var listenCount: Int = 0
        var lastListenedAt: Date?
        var universe: Universe?
        // v1.0–v1.3 shipped without a VersionedSchema and declared this to-many
        // relationship as non-optional `[Mood]`. SchemaV1 must reproduce that exact
        // shape so SwiftData can identify the pre-versioned store as version 1 and
        // start the staged migration (otherwise: "unknown model version", error 134504).
        var moods: [Mood] = []

        init(
            episodeNumber: Int = 0,
            title: String = "",
            releaseYear: Int = 0,
            personalNote: String? = nil,
            isListened: Bool = false,
            rating: Int? = nil,
            listenCount: Int = 0,
            lastListenedAt: Date? = nil,
            universe: Universe? = nil,
            moods: [Mood] = []
        ) {
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

    @Model
    final class Mood {
        var name: String = ""
        var iconName: String?
        // Non-optional to match the pre-versioned v1.0 model exactly (see Episode.moods).
        var episodes: [Episode] = []

        init(name: String = "", iconName: String? = nil, episodes: [Episode] = []) {
            self.name = name
            self.iconName = iconName
            self.episodes = episodes
        }
    }

    @Model
    final class Universe {
        var name: String = ""
        // Non-optional to match the pre-versioned v1.0 model exactly (see Episode.moods).
        var episodes: [Episode] = []

        init(name: String = "", episodes: [Episode] = []) {
            self.name = name
            self.episodes = episodes
        }
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }

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
        @Relationship(inverse: \Universe.episodeRelationships) var universe: Universe?
        @Relationship(originalName: "moods", inverse: \Mood.episodeRelationships) var moodRelationships: [Mood]? = []

        init() {}
    }

    @Model
    final class Mood {
        var id: UUID = UUID()
        var name: String = ""
        var iconName: String?
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }

    @Model
    final class Universe {
        var id: UUID = UUID()
        var name: String = ""
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }

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
        @Relationship(inverse: \Universe.episodeRelationships) var universe: Universe?
        @Relationship(originalName: "moods", inverse: \Mood.episodeRelationships) var moodRelationships: [Mood]? = []

        init() {}
    }

    @Model
    final class Mood {
        var id: UUID = UUID()
        var name: String = ""
        var iconName: String?
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }

    @Model
    final class Universe {
        var id: UUID = UUID()
        var name: String = ""
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }
}

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }

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
        @Relationship(inverse: \Universe.episodeRelationships) var universe: Universe?
        @Relationship(originalName: "moods", inverse: \Mood.episodeRelationships) var moodRelationships: [Mood]? = []

        init() {}
    }

    @Model
    final class Mood {
        var id: UUID = UUID()
        var name: String = ""
        var iconName: String?
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }

    @Model
    final class Universe {
        var id: UUID = UUID()
        var name: String = ""
        var syncKey: String?
        var coverImageName: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }
}

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }

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
        @Relationship(inverse: \Universe.episodeRelationships) var universe: Universe?
        @Relationship(originalName: "moods", inverse: \Mood.episodeRelationships) var moodRelationships: [Mood]? = []

        init() {}
    }

    @Model
    final class Mood {
        var id: UUID = UUID()
        var name: String = ""
        var iconName: String?
        var syncKey: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }

    @Model
    final class Universe {
        var id: UUID = UUID()
        var name: String = ""
        var syncKey: String?
        var coverImageName: String?
        @Relationship(originalName: "episodes") var episodeRelationships: [Episode]? = []

        init() {}
    }
}

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Episode.self, Mood.self, Universe.self]
    }
}
