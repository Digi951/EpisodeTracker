// EpisodeTracker/Features/Widget/WidgetSnapshotCoordinator.swift
import Foundation

/// Computes a content signature and deduplicates widget snapshot writes.
///
/// The signature depends on the order of the `episodes` and `universes` arrays.
/// Callers must provide stably-ordered arrays (e.g. via `@Query(sort:)`).
@MainActor
@Observable
final class WidgetSnapshotCoordinator {
    private var lastSignature: String?

    /// Test-Hook: wird statt des echten Snapshot-Writes aufgerufen, wenn gesetzt.
    var writeHook: (() -> Void)?

    func refresh(libraryTitle: String, universes: [Universe], episodes: [Episode]) {
        let signature = Self.signature(
            libraryTitle: libraryTitle,
            universes: universes,
            episodes: episodes
        )
        guard signature != lastSignature else { return }
        lastSignature = signature

        if let writeHook {
            writeHook()
        } else {
            WidgetSyncStore.writeSnapshot(
                libraryTitle: libraryTitle,
                universes: universes,
                episodes: episodes
            )
        }
    }

    static func signature(libraryTitle: String, universes: [Universe], episodes: [Episode]) -> String {
        let episodeSignature = episodes.map { episode in
            let universeName = episode.universe?.name ?? ""
            let rating = episode.rating.map(String.init) ?? ""
            let listenedAt = episode.lastListenedAt?.timeIntervalSince1970.description ?? ""
            return [
                episode.id.uuidString,
                String(episode.episodeNumber),
                episode.title,
                String(episode.releaseYear),
                universeName,
                episode.isListened ? "1" : "0",
                episode.isBookmarked ? "1" : "0",
                episode.kindRaw,
                rating,
                listenedAt,
            ].joined(separator: "|")
        }
        .joined(separator: "\n")

        let universeSignature = universes.map(\.name).joined(separator: "\n")
        return [libraryTitle, universeSignature, episodeSignature].joined(separator: "\u{1F}")
    }
}
