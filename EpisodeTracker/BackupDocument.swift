import Foundation
import UniformTypeIdentifiers
import SwiftUI
import SwiftData

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

/// Merged ein importiertes Backup in die bestehende Bibliothek. Bewusst aus
/// `SettingsView` herausgezogen: das war die einzige unmittelbare Datenmodell-
/// Operation, die auf `@Query`/`@Environment` saß und dadurch nicht ohne echte
/// UI testbar war — bei der riskantesten Operation der App (sie fasst die
/// gesamte Bibliothek an) das teuerste denkbare Blindspot.
enum BackupRestorer {
    /// Identität beim Matching läuft über dieselbe Sync-Key-Logik wie beim
    /// CloudKit-Merge (`Episode.makeSyncKey` / `EntityDeduplicator`), statt sie
    /// hier ein zweites Mal von Hand nachzubauen.
    static func apply(
        _ payload: BackupPayload,
        existingUniverses: [Universe],
        existingMoods: [Mood],
        existingEpisodes: [Episode],
        context: ModelContext
    ) {
        var universesByKey = Dictionary(
            existingUniverses.map { (CatalogLibraryMatcher.normalizedCollectionKey($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for universeData in payload.collections ?? [] {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(universeData.name)
            guard universesByKey[key] == nil else { continue }
            let newUniverse = Universe(name: universeData.name)
            context.insert(newUniverse)
            universesByKey[key] = newUniverse
        }

        var moodsByKey = Dictionary(
            existingMoods.map { (CatalogLibraryMatcher.normalizedCollectionKey($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for moodData in payload.moods {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(moodData.name)
            if let existing = moodsByKey[key] {
                existing.iconName = moodData.iconName
            } else {
                let newMood = Mood(name: moodData.name, iconName: moodData.iconName)
                context.insert(newMood)
                moodsByKey[key] = newMood
            }
        }

        var episodesByKey = Dictionary(
            existingEpisodes.map { ($0.resolvedSyncKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for episodeData in payload.episodes {
            let assignedMoods = episodeData.moodNames.compactMap {
                moodsByKey[CatalogLibraryMatcher.normalizedCollectionKey($0)]
            }

            let universeName = episodeData.collectionName ?? "Allgemein"
            let universeKey = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
            let assignedUniverse: Universe
            if let existingUniverse = universesByKey[universeKey] {
                assignedUniverse = existingUniverse
            } else {
                let newUniverse = Universe(name: universeName)
                context.insert(newUniverse)
                universesByKey[universeKey] = newUniverse
                assignedUniverse = newUniverse
            }

            let episodeKey = Episode.makeSyncKey(
                universeSyncKey: assignedUniverse.resolvedSyncKey,
                kind: episodeData.kind,
                episodeNumber: episodeData.episodeNumber,
                catalogSlug: episodeData.catalogSlug
            )

            if let existingEpisode = episodesByKey[episodeKey] {
                existingEpisode.title = episodeData.title
                existingEpisode.releaseYear = episodeData.releaseYear
                existingEpisode.personalNote = episodeData.personalNote
                existingEpisode.isListened = episodeData.isListened
                existingEpisode.rating = episodeData.rating
                existingEpisode.listenCount = episodeData.listenCount
                existingEpisode.lastListenedAt = episodeData.lastListenedAt
                existingEpisode.universe = assignedUniverse
                existingEpisode.moods = assignedMoods
                existingEpisode.kind = episodeData.kind
                if let slug = episodeData.catalogSlug { existingEpisode.catalogSlug = slug }
                existingEpisode.refreshSyncKeyIfPossible()
            } else {
                let newEpisode = Episode(
                    episodeNumber: episodeData.episodeNumber,
                    title: episodeData.title,
                    releaseYear: episodeData.releaseYear,
                    kind: episodeData.kind,
                    catalogSlug: episodeData.catalogSlug,
                    personalNote: episodeData.personalNote,
                    isListened: episodeData.isListened,
                    rating: episodeData.rating,
                    listenCount: episodeData.listenCount,
                    lastListenedAt: episodeData.lastListenedAt,
                    universe: assignedUniverse,
                    moods: assignedMoods
                )
                context.insert(newEpisode)
                episodesByKey[episodeKey] = newEpisode
            }
        }
    }
}

/// Besitzt Zustand und Ablauf für Backup-Export/-Import: Statusmeldung,
/// Datei-Picker-Sichtbarkeit, Import-Bestätigung. Aus `SettingsView`
/// herausgezogen, die davor vier unabhängige Einstellungs-Domänen (App-Icon,
/// Backup, Anzeige-Reset, Sync-Diagnose) in einer View bündelte. Bleibt hier
/// statt in einer eigenen Datei, weil `BackupDocument.swift` bereits alles
/// hält, was zu "Backup" gehört.
@Observable
final class BackupExportImportController {
    var statusMessage: String?
    var statusIsError = false
    var showingImporter = false
    var showingExporter = false
    var exportDocument: JSONBackupDocument?
    var pendingImportURL: URL?

    var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "HoerspielLog-Backup-\(formatter.string(from: .now))"
    }

    func export(universes: [Universe], moods: [Mood], episodes: [Episode]) {
        do {
            let payload = Self.makePayload(universes: universes, moods: moods, episodes: episodes)
            let data = try JSONEncoder.backupEncoder.encode(payload)
            exportDocument = JSONBackupDocument(data: data)
            showingExporter = true
            statusMessage = nil
        } catch {
            statusIsError = true
            statusMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusIsError = false
            statusMessage = "Backup wurde exportiert."
        case .failure(let error):
            statusIsError = true
            statusMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func handleImportPick(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            pendingImportURL = url
        case .failure(let error):
            statusIsError = true
            statusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func cancelImport() {
        pendingImportURL = nil
    }

    func confirmImport(
        existingUniverses: [Universe],
        existingMoods: [Mood],
        existingEpisodes: [Episode],
        context: ModelContext
    ) {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil

        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: data)
            BackupRestorer.apply(
                payload,
                existingUniverses: existingUniverses,
                existingMoods: existingMoods,
                existingEpisodes: existingEpisodes,
                context: context
            )

            statusIsError = false
            statusMessage = "Backup importiert: \(payload.episodes.count) Folgen, \(payload.moods.count) Stimmungen."
        } catch {
            statusIsError = true
            statusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private static func makePayload(universes: [Universe], moods: [Mood], episodes: [Episode]) -> BackupPayload {
        let universesData = universes.map { universe in
            BackupCollection(name: universe.name)
        }
        let moodsData = moods.map { mood in
            BackupMood(name: mood.name, iconName: mood.iconName)
        }
        let episodesData = episodes.map { episode in
            BackupEpisode(
                episodeNumber: episode.episodeNumber,
                kind: episode.kind,
                catalogSlug: episode.catalogSlug,
                title: episode.title,
                releaseYear: episode.releaseYear,
                personalNote: episode.personalNote,
                isListened: episode.isListened,
                rating: episode.rating,
                listenCount: episode.listenCount,
                lastListenedAt: episode.lastListenedAt,
                collectionName: episode.universe?.name,
                moodNames: episode.moods.map(\.name)
            )
        }
        return BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: universesData,
            moods: moodsData,
            episodes: episodesData
        )
    }
}
