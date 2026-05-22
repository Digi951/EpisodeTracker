import Foundation
import WidgetKit

enum WidgetSyncStore {
    static let appGroupIdentifier = "group.com.digi.episodetracker"
    static let snapshotFileName = "widget-library-snapshot.json"
    private static let coversFolderName = "covers"

    static func writeSnapshot(
        libraryTitle: String,
        universes: [Universe],
        episodes: [Episode],
        fileManager: FileManager = .default
    ) {
        guard let fileURL = snapshotFileURL(fileManager: fileManager) else { return }

        let trimmedTitle = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle = trimmedTitle.isEmpty ? "Meine Hörspiele" : trimmedTitle

        let appGroupCoversURL = appGroupContainerURL(fileManager: fileManager)?
            .appendingPathComponent(coversFolderName, isDirectory: true)
        if let dir = appGroupCoversURL {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let mainAppCoversURL = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)?
            .appendingPathComponent("EpisodeTracker", isDirectory: true)
            .appendingPathComponent("covers", isDirectory: true)

        let snapshot = WidgetLibrarySnapshot(
            generatedAt: .now,
            libraryTitle: effectiveTitle,
            universes: universes.map(\.name).sorted { $0.localizedCompare($1) == .orderedAscending },
            episodes: episodes.map { episode in
                let coverName = episode.coverImageName.flatMap { $0.isEmpty ? nil : $0 }
                if let name = coverName,
                   let src = mainAppCoversURL?.appendingPathComponent("\(name).jpg"),
                   let dst = appGroupCoversURL?.appendingPathComponent("\(name).jpg"),
                   fileManager.fileExists(atPath: src.path) {
                    try? fileManager.removeItem(at: dst)
                    try? fileManager.copyItem(at: src, to: dst)
                }
                return WidgetEpisodeSnapshot(
                    id: episode.id,
                    episodeNumber: episode.episodeNumber,
                    title: episode.title,
                    releaseYear: episode.releaseYear,
                    universeName: episode.universe?.name,
                    isListened: episode.isListened,
                    rating: episode.rating,
                    lastListenedAt: episode.lastListenedAt,
                    coverImageName: coverName
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
        appGroupContainerURL(fileManager: fileManager)?
            .appendingPathComponent(snapshotFileName)
    }

    private static func appGroupContainerURL(fileManager: FileManager) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
}
