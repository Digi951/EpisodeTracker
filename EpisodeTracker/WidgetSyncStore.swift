import Foundation
import WidgetKit

enum WidgetSyncStore {
    static let appGroupIdentifier = "group.com.digi.episodetracker"
    static let snapshotFileName = "widget-library-snapshot.json"

    static func writeSnapshot(
        libraryTitle: String,
        universes: [Universe],
        episodes: [Episode],
        fileManager: FileManager = .default
    ) {
        guard let fileURL = snapshotFileURL(fileManager: fileManager) else { return }

        let trimmedTitle = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle = trimmedTitle.isEmpty ? "Meine Hörspiele" : trimmedTitle

        let snapshot = WidgetLibrarySnapshot(
            generatedAt: .now,
            libraryTitle: effectiveTitle,
            universes: universes.map(\.name).sorted { $0.localizedCompare($1) == .orderedAscending },
            episodes: episodes.map { episode in
                WidgetEpisodeSnapshot(
                    id: episode.id,
                    episodeNumber: episode.episodeNumber,
                    title: episode.title,
                    releaseYear: episode.releaseYear,
                    universeName: episode.universe?.name,
                    isListened: episode.isListened,
                    rating: episode.rating,
                    lastListenedAt: episode.lastListenedAt
                )
            }
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            #if DEBUG
            print("Widget snapshot write failed: \(error)")
            #endif
        }
    }

    private static func snapshotFileURL(fileManager: FileManager) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName)
    }
}
