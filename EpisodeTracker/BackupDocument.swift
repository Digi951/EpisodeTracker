import Foundation
import UniformTypeIdentifiers
import SwiftUI

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupPayload: Codable {
    let exportedAt: Date
    let schemaVersion: Int
    let collections: [BackupCollection]?
    let moods: [BackupMood]
    let episodes: [BackupEpisode]
}

struct BackupCollection: Codable {
    let name: String
}

struct BackupMood: Codable {
    let name: String
    let iconName: String?
}

struct BackupEpisode: Codable {
    let episodeNumber: Int
    let kind: EpisodeKind
    let catalogSlug: String?
    let title: String
    let releaseYear: Int
    let personalNote: String?
    let isListened: Bool
    let rating: Int?
    let listenCount: Int
    let lastListenedAt: Date?
    let collectionName: String?
    let moodNames: [String]

    init(
        episodeNumber: Int,
        kind: EpisodeKind = .regular,
        catalogSlug: String? = nil,
        title: String,
        releaseYear: Int,
        personalNote: String?,
        isListened: Bool,
        rating: Int?,
        listenCount: Int,
        lastListenedAt: Date?,
        collectionName: String?,
        moodNames: [String]
    ) {
        self.episodeNumber = episodeNumber
        self.kind = kind
        self.catalogSlug = catalogSlug
        self.title = title
        self.releaseYear = releaseYear
        self.personalNote = personalNote
        self.isListened = isListened
        self.rating = rating
        self.listenCount = listenCount
        self.lastListenedAt = lastListenedAt
        self.collectionName = collectionName
        self.moodNames = moodNames
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodeNumber = try c.decode(Int.self, forKey: .episodeNumber)
        kind = try c.decodeIfPresent(EpisodeKind.self, forKey: .kind) ?? .regular
        catalogSlug = try c.decodeIfPresent(String.self, forKey: .catalogSlug)
        title = try c.decode(String.self, forKey: .title)
        releaseYear = try c.decode(Int.self, forKey: .releaseYear)
        personalNote = try c.decodeIfPresent(String.self, forKey: .personalNote)
        isListened = try c.decode(Bool.self, forKey: .isListened)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        listenCount = try c.decode(Int.self, forKey: .listenCount)
        lastListenedAt = try c.decodeIfPresent(Date.self, forKey: .lastListenedAt)
        collectionName = try c.decodeIfPresent(String.self, forKey: .collectionName)
        moodNames = try c.decode([String].self, forKey: .moodNames)
    }
}

extension JSONEncoder {
    static let backupEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let backupDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
