import XCTest
@testable import EpisodeTracker

final class NewsOverviewOrganizerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func makeEvent(
        kind: NewsEventKind,
        episodeNumber: Int? = nil,
        title: String = "Titel",
        revision: String = "1",
        discoveredAt: Date,
        seenAt: Date? = nil
    ) -> NewsEvent {
        NewsEvent(
            kind: kind,
            universeName: "Die drei ???",
            catalogID: "die-drei-fragezeichen",
            episodeNumber: episodeNumber,
            title: title,
            revision: revision,
            discoveredAt: discoveredAt,
            seenAt: seenAt
        )
    }

    // MARK: Neu erschienen — 30-Tage-Fenster

    func testRecentSeenEventIsVisibleByDefault() {
        let event = makeEvent(kind: .newEpisode, discoveredAt: now.addingTimeInterval(-5 * 24 * 60 * 60), seenAt: now)
        let sections = NewsOverviewOrganizer.sections(from: [event], now: now)

        XCTAssertEqual(sections.neuErschienen, [event])
        XCTAssertFalse(sections.hasHiddenOlderNeuErschienen)
    }

    func testOldSeenEventIsHiddenByDefaultButFlagged() {
        let event = makeEvent(kind: .newEpisode, discoveredAt: now.addingTimeInterval(-31 * 24 * 60 * 60), seenAt: now)
        let sections = NewsOverviewOrganizer.sections(from: [event], now: now)

        XCTAssertEqual(sections.neuErschienen, [])
        XCTAssertTrue(sections.hasHiddenOlderNeuErschienen)
    }

    func testUnseenEventSurvivesTheWindowRegardlessOfAge() {
        let event = makeEvent(kind: .newEpisode, discoveredAt: now.addingTimeInterval(-400 * 24 * 60 * 60), seenAt: nil)
        let sections = NewsOverviewOrganizer.sections(from: [event], now: now)

        XCTAssertEqual(sections.neuErschienen, [event])
        XCTAssertFalse(sections.hasHiddenOlderNeuErschienen)
    }

    func testShowAllNeuErschienenIncludesOlderEntriesAndClearsTheFlag() {
        let old = makeEvent(kind: .newEpisode, discoveredAt: now.addingTimeInterval(-90 * 24 * 60 * 60), seenAt: now)
        let sections = NewsOverviewOrganizer.sections(from: [old], now: now, showAllNeuErschienen: true)

        XCTAssertEqual(sections.neuErschienen, [old])
        XCTAssertFalse(sections.hasHiddenOlderNeuErschienen)
    }

    func testNeuErschienenIsSortedNewestFirst() {
        let older = makeEvent(kind: .newEpisode, episodeNumber: 1, discoveredAt: now.addingTimeInterval(-2 * 24 * 60 * 60))
        let newer = makeEvent(kind: .newEpisode, episodeNumber: 2, discoveredAt: now)
        let sections = NewsOverviewOrganizer.sections(from: [older, newer], now: now)

        XCTAssertEqual(sections.neuErschienen.map(\.episodeNumber), [2, 1])
    }

    // MARK: Bald verfügbar — Datumsgruppen

    func testUpcomingEventsAreGroupedAndSortedByDateAscending() {
        let laterDay = "2026-09-20"
        let earlierDay = "2026-09-11"
        let later = makeEvent(kind: .upcoming, episodeNumber: 1, revision: laterDay, discoveredAt: now)
        let earlier = makeEvent(kind: .upcoming, episodeNumber: 2, revision: earlierDay, discoveredAt: now)

        let sections = NewsOverviewOrganizer.sections(from: [later, earlier], now: now)

        XCTAssertEqual(sections.baldVerfuegbar.count, 2)
        XCTAssertEqual(sections.baldVerfuegbar.first?.events, [earlier])
        XCTAssertEqual(sections.baldVerfuegbar.last?.events, [later])
    }

    func testUpcomingEventsWithUnresolvableDateFormIntoTerminOffenGroupSortedLast() {
        let dated = makeEvent(kind: .upcoming, episodeNumber: 1, revision: "2026-09-11", discoveredAt: now)
        let undated = makeEvent(kind: .upcoming, episodeNumber: 2, revision: "unbekannt", discoveredAt: now)

        let sections = NewsOverviewOrganizer.sections(from: [dated, undated], now: now)

        XCTAssertEqual(sections.baldVerfuegbar.count, 2)
        XCTAssertNil(sections.baldVerfuegbar.last?.date)
        XCTAssertEqual(sections.baldVerfuegbar.last?.events, [undated])
        XCTAssertEqual(sections.baldVerfuegbar.last?.id, "termin-offen")
    }

    func testMultipleReleasesOnTheSameDayShareOneGroup() {
        let first = makeEvent(kind: .upcoming, episodeNumber: 5, title: "B-Folge", revision: "2026-09-11", discoveredAt: now)
        let second = makeEvent(kind: .upcoming, episodeNumber: 4, title: "A-Folge", revision: "2026-09-11", discoveredAt: now)

        let sections = NewsOverviewOrganizer.sections(from: [first, second], now: now)

        XCTAssertEqual(sections.baldVerfuegbar.count, 1)
        XCTAssertEqual(sections.baldVerfuegbar.first?.events.map(\.episodeNumber), [4, 5])
    }

    // MARK: Neue Reihen

    func testNewCatalogEventsAreSortedNewestFirst() {
        let older = NewsEvent(kind: .newCatalog, universeName: "TKKG", catalogID: "tkkg", title: "TKKG", revision: "tkkg", discoveredAt: now.addingTimeInterval(-3600))
        let newer = NewsEvent(kind: .newCatalog, universeName: "Fünf Freunde", catalogID: "fuenf-freunde", title: "Fünf Freunde", revision: "fuenf-freunde", discoveredAt: now)

        let sections = NewsOverviewOrganizer.sections(from: [older, newer], now: now)

        XCTAssertEqual(sections.neueReihen.map(\.catalogID), ["fuenf-freunde", "tkkg"])
    }

    // MARK: Kind-Trennung

    func testKindsDoNotLeakBetweenSections() {
        let newEpisode = makeEvent(kind: .newEpisode, discoveredAt: now)
        let upcoming = makeEvent(kind: .upcoming, revision: "2026-09-11", discoveredAt: now)
        let newCatalog = NewsEvent(kind: .newCatalog, universeName: "TKKG", catalogID: "tkkg", title: "TKKG", revision: "tkkg", discoveredAt: now)

        let sections = NewsOverviewOrganizer.sections(from: [newEpisode, upcoming, newCatalog], now: now)

        XCTAssertEqual(sections.neuErschienen, [newEpisode])
        XCTAssertEqual(sections.baldVerfuegbar.flatMap(\.events), [upcoming])
        XCTAssertEqual(sections.neueReihen, [newCatalog])
    }
}
