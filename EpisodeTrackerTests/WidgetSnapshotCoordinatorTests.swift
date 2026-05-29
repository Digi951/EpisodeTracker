// EpisodeTrackerTests/WidgetSnapshotCoordinatorTests.swift
import XCTest
@testable import EpisodeTracker

@MainActor
final class WidgetSnapshotCoordinatorTests: XCTestCase {
    func testSignatureChangesWhenEpisodeListenStatusChanges() {
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)

        let before = WidgetSnapshotCoordinator.signature(
            libraryTitle: "Meine Hörspiele", universes: [universe], episodes: [episode]
        )
        episode.isListened = true
        let after = WidgetSnapshotCoordinator.signature(
            libraryTitle: "Meine Hörspiele", universes: [universe], episodes: [episode]
        )

        XCTAssertNotEqual(before, after)
    }

    func testSignatureStableForUnchangedData() {
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)

        let a = WidgetSnapshotCoordinator.signature(
            libraryTitle: "T", universes: [universe], episodes: [episode]
        )
        let b = WidgetSnapshotCoordinator.signature(
            libraryTitle: "T", universes: [universe], episodes: [episode]
        )

        XCTAssertEqual(a, b)
    }

    func testRefreshSkipsWriteWhenSignatureUnchanged() {
        let coordinator = WidgetSnapshotCoordinator()
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)
        var writeCount = 0
        coordinator.writeHook = { writeCount += 1 }

        coordinator.refresh(libraryTitle: "T", universes: [universe], episodes: [episode])
        coordinator.refresh(libraryTitle: "T", universes: [universe], episodes: [episode])

        XCTAssertEqual(writeCount, 1, "Zweiter Refresh ohne Änderung schreibt nicht erneut")

        episode.isListened = true
        coordinator.refresh(libraryTitle: "T", universes: [universe], episodes: [episode])
        XCTAssertEqual(writeCount, 2, "Echte Änderung schreibt erneut")
    }
}
