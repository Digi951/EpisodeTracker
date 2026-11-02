import XCTest
@testable import EpisodeTracker

final class YearInReviewEngineTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 20) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func episode(
        _ number: Int,
        universe: Universe,
        listenedAt: Date?,
        listenCount: Int = 1,
        rating: Int? = nil,
        isHidden: Bool = false,
        moods: [Mood] = []
    ) -> Episode {
        Episode(
            episodeNumber: number,
            title: "Folge \(number)",
            releaseYear: 2000,
            isListened: listenCount > 0,
            rating: rating,
            listenCount: listenCount,
            lastListenedAt: listenedAt,
            isHidden: isHidden,
            universe: universe,
            moods: moods
        )
    }

    func testCountsOnlyListenedVisibleEpisodesOfTheYear() {
        let tkkg = Universe(name: "TKKG")
        let episodes = [
            episode(1, universe: tkkg, listenedAt: date(2026, 3, 1)),
            episode(2, universe: tkkg, listenedAt: date(2025, 12, 31)),
            episode(3, universe: tkkg, listenedAt: date(2026, 5, 1), isHidden: true),
            episode(4, universe: tkkg, listenedAt: nil, listenCount: 0),
            episode(5, universe: tkkg, listenedAt: date(2026, 12, 31, hour: 23))
        ]

        let engine = YearInReviewEngine(episodes: episodes, year: 2026, calendar: calendar)

        XCTAssertEqual(engine.episodes.map(\.episodeNumber).sorted(), [1, 5])
        XCTAssertEqual(YearInReviewEngine.availableYears(episodes: episodes, calendar: calendar), [2025, 2026])
    }

    func testFavoriteSeriesByCountThenName() {
        let tkkg = Universe(name: "TKKG")
        let fragezeichen = Universe(name: "Die drei ???")
        let episodes = [
            episode(1, universe: tkkg, listenedAt: date(2026, 1, 5)),
            episode(2, universe: tkkg, listenedAt: date(2026, 2, 5)),
            episode(1, universe: fragezeichen, listenedAt: date(2026, 3, 5)),
            episode(2, universe: fragezeichen, listenedAt: date(2026, 4, 5))
        ]

        let series = YearInReviewEngine(episodes: episodes, year: 2026, calendar: calendar).favoriteSeries

        XCTAssertEqual(series?.name, "Die drei ???")
        XCTAssertEqual(series?.count, 2)
    }

    /// Ein Tag mit vielen Einträgen ist Nachtragen, kein Hören, und darf den
    /// stärksten Monat nicht bestimmen.
    func testStrongestMonthIgnoresBulkDays() {
        let tkkg = Universe(name: "TKKG")
        var episodes = (1...YearInReviewEngine.bulkDayThreshold).map {
            episode($0, universe: tkkg, listenedAt: date(2026, 7, 12))
        }
        episodes += [
            episode(101, universe: tkkg, listenedAt: date(2026, 11, 2)),
            episode(102, universe: tkkg, listenedAt: date(2026, 11, 9)),
            episode(103, universe: tkkg, listenedAt: date(2026, 3, 1))
        ]

        let month = YearInReviewEngine(episodes: episodes, year: 2026, calendar: calendar).strongestMonth

        XCTAssertEqual(month?.month, 11)
        XCTAssertEqual(month?.count, 2)
    }

    func testStrongestMonthNeedsEnoughEntries() {
        let tkkg = Universe(name: "TKKG")
        let episodes = [
            episode(1, universe: tkkg, listenedAt: date(2026, 1, 5)),
            episode(2, universe: tkkg, listenedAt: date(2026, 1, 6))
        ]

        XCTAssertNil(YearInReviewEngine(episodes: episodes, year: 2026, calendar: calendar).strongestMonth)
    }

    func testPodiumAndMoodsOnlyFromTheYear() {
        let tkkg = Universe(name: "TKKG")
        let gruselig = Mood(name: "Gruselig", iconName: "😱")
        let episodes = [
            episode(1, universe: tkkg, listenedAt: date(2026, 1, 5), rating: 3, moods: [gruselig]),
            episode(2, universe: tkkg, listenedAt: date(2026, 2, 5), rating: 5, moods: [gruselig]),
            episode(3, universe: tkkg, listenedAt: date(2025, 2, 5), rating: 5, moods: [gruselig]),
            episode(4, universe: tkkg, listenedAt: date(2026, 3, 5))
        ]

        let engine = YearInReviewEngine(episodes: episodes, year: 2026, calendar: calendar)

        XCTAssertEqual(engine.podium.map(\.episodeNumber), [2, 1])
        XCTAssertEqual(engine.topMoods.first?.mood.name, "Gruselig")
        XCTAssertEqual(engine.topMoods.first?.count, 2)
    }

    func testDefaultYearIsPreviousYearInJanuary() {
        XCTAssertEqual(YearInReviewEngine.defaultYear(on: date(2027, 1, 3), calendar: calendar), 2026)
        XCTAssertEqual(YearInReviewEngine.defaultYear(on: date(2026, 12, 28), calendar: calendar), 2026)
        XCTAssertEqual(YearInReviewEngine.defaultYear(on: date(2026, 6, 1), calendar: calendar), 2026)
    }
}

final class YearInReviewBannerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testWindowRunsFromDecember27ToJanuary6() {
        XCTAssertNil(YearInReviewBanner.year(on: date(2026, 12, 26), calendar: calendar))
        XCTAssertEqual(YearInReviewBanner.year(on: date(2026, 12, 27), calendar: calendar), 2026)
        XCTAssertEqual(YearInReviewBanner.year(on: date(2027, 1, 6), calendar: calendar), 2026)
        XCTAssertNil(YearInReviewBanner.year(on: date(2027, 1, 7), calendar: calendar))
    }

    func testPendingYearNeedsEntriesToggleAndNoDismissal() {
        let tkkg = Universe(name: "TKKG")
        let episodes = [
            Episode(episodeNumber: 1, title: "Folge 1", releaseYear: 2000, isListened: true,
                    listenCount: 1, lastListenedAt: date(2026, 5, 1), universe: tkkg)
        ]
        let now = date(2026, 12, 28)

        XCTAssertEqual(YearInReviewBanner.pendingYear(episodes: episodes, dismissedYear: 0, accentsEnabled: true, on: now, calendar: calendar), 2026)
        XCTAssertNil(YearInReviewBanner.pendingYear(episodes: episodes, dismissedYear: 2026, accentsEnabled: true, on: now, calendar: calendar))
        XCTAssertNil(YearInReviewBanner.pendingYear(episodes: episodes, dismissedYear: 0, accentsEnabled: false, on: now, calendar: calendar))
        XCTAssertNil(YearInReviewBanner.pendingYear(episodes: [], dismissedYear: 0, accentsEnabled: true, on: now, calendar: calendar))
        // Weggeklicktes Vorjahr hält das neue Jahr nicht auf.
        XCTAssertEqual(YearInReviewBanner.pendingYear(episodes: episodes, dismissedYear: 2025, accentsEnabled: true, on: now, calendar: calendar), 2026)
    }
}
