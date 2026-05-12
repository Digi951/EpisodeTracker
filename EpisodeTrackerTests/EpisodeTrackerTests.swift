import XCTest
import SwiftData
@testable import EpisodeTracker

final class EpisodeTrackerTests: XCTestCase {
    private let parser = CatalogParser()

    func testParsesWrappedCatalogEntriesWithFallbackCollection() throws {
        let json = """
        {
          "collectionName": "Die drei ???",
          "entries": [
            {
              "number": 1,
              "title": "und der Super-Papagei",
              "releaseYear": 1979
            }
          ]
        }
        """

        let entries = try parser.parseCatalogEntries(
            from: Data(json.utf8),
            fallbackCollectionName: "Fallback"
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].number, 1)
        XCTAssertEqual(entries[0].title, "und der Super-Papagei")
        XCTAssertEqual(entries[0].releaseYear, 1979)
        XCTAssertEqual(entries[0].collectionName, "Die drei ???")
    }

    func testParsesFlatCatalogEntriesWithFallbackCollection() throws {
        let json = """
        [
          {
            "number": 1,
            "title": "und der Super-Papagei",
            "releaseYear": 1979
          }
        ]
        """

        let entries = try parser.parseCatalogEntries(
            from: Data(json.utf8),
            fallbackCollectionName: "Die drei ???"
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].collectionName, "Die drei ???")
    }

    func testParsesManifestAndNormalizesGitHubBlobURLs() throws {
        let json = """
        {
          "schemaVersion": 1,
          "updatedAt": "2026-05-03",
          "catalogs": [
            {
              "id": "die-drei-fragezeichen",
              "name": "Die drei ???",
              "language": "de",
              "url": "https://github.com/Digi951/hoerspiel-kataloge/blob/main/catalogs/The_three_questionmarks.json"
            }
          ]
        }
        """

        let manifest = try parser.parseManifest(from: Data(json.utf8))

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.catalogs.count, 1)
        XCTAssertEqual(manifest.catalogs[0].url.absoluteString, "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/The_three_questionmarks.json")
    }

    func testContainerFactoryUsesPreviewModeForPreviewEnvironment() {
        let mode = AppModelContainerFactory.resolveMode(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )

        XCTAssertEqual(mode, .previewInMemory)
    }

    func testContainerFactoryDefaultsToPersistentMode() {
        let mode = AppModelContainerFactory.resolveMode(environment: [:])

        XCTAssertEqual(mode, .localPersistent)
    }

    func testContainerFactoryBuildsExpectedPersistentStoreURL() {
        let fileManager = FileManager.default
        let storeURL = AppModelContainerFactory.persistentStoreURL(fileManager: fileManager)

        XCTAssertEqual(storeURL.lastPathComponent, "EpisodeTracker.store")
        XCTAssertEqual(storeURL.deletingLastPathComponent().lastPathComponent, "EpisodeTracker")
    }

    @MainActor
    func testUniverseAndMoodDefaultToDeterministicSyncKeys() {
        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Gruselig", iconName: "😱")

        XCTAssertEqual(universe.resolvedSyncKey, "universe:die drei ???")
        XCTAssertEqual(mood.resolvedSyncKey, "mood:gruselig")
    }

    @MainActor
    func testEpisodeSyncKeyUsesUniverseSyncKeyAndNumber() {
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(
            episodeNumber: 7,
            title: "und der unheimliche Drache",
            releaseYear: 1979,
            universe: universe
        )

        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:die drei ???#7")
    }

    @MainActor
    func testEpisodeRefreshesSyncKeyAfterUniverseAssignment() {
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: nil
        )
        let originalSyncKey = episode.resolvedSyncKey
        let universe = Universe(name: "Die drei ???")

        episode.universe = universe
        episode.refreshSyncKeyIfPossible()

        XCTAssertNotEqual(episode.resolvedSyncKey, originalSyncKey)
        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:die drei ???#1")
    }

    func testFreemiumPreparationDoesNotBlockCreationYet() {
        XCTAssertFalse(FreemiumAccess.isEnforcementEnabled)
        XCTAssertTrue(
            FreemiumAccess.canCreateEpisode(
                currentEpisodeCount: FreemiumAccess.freeEpisodeLimit,
                isPlusUnlocked: false
            )
        )
    }

    func testFreemiumUsageTextShowsFreeLimitAndPlusState() {
        XCTAssertEqual(
            FreemiumAccess.freePlanUsageText(currentEpisodeCount: 12, isPlusUnlocked: false),
            "12 von \(FreemiumAccess.freeEpisodeLimit)"
        )
        XCTAssertEqual(
            FreemiumAccess.freePlanUsageText(currentEpisodeCount: 99, isPlusUnlocked: true),
            "Unbegrenzt"
        )
    }

    func testLargeNumberSortedLibraryGroupsIntoEpisodeRanges() {
        let universe = Universe(name: "Die drei ???")
        let episodes = (1...55).map { number in
            Episode(episodeNumber: number, title: "Folge \(number)", releaseYear: 1980, universe: universe)
        }

        let sorted = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: universe,
            filterMood: nil,
            statusFilter: .all,
            sortOrder: .number
        )
        let groups = EpisodeListOrganizer.groups(
            for: sorted,
            sortOrder: .number,
            filterUniverse: universe,
            universeCount: 1
        )

        XCTAssertEqual(groups.map(\.title), ["1-25", "26-50", "51-75"])
        XCTAssertEqual(groups.map(\.episodes.count), [25, 25, 5])
    }

    func testSmallLibrariesStayUngroupedByDefault() {
        let universe = Universe(name: "Die drei ???")
        let episodes = [
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, universe: universe)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2
        )

        XCTAssertTrue(groups.isEmpty)
    }

    func testMultipleCatalogEpisodesGroupEarlyForOverviewProgress() {
        let firstUniverse = Universe(name: "Die drei ???")
        let secondUniverse = Universe(name: "TKKG")
        let episodes = [
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, universe: firstUniverse),
            Episode(episodeNumber: 1, title: "Die Jagd nach den Millionendieben", releaseYear: 1981, universe: secondUniverse)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.title), ["Die drei ???", "TKKG"])
    }

    func testStatusFilterKeepsOnlyOpenEpisodes() {
        let episodes = [
            Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1980, isListened: true),
            Episode(episodeNumber: 2, title: "Offen", releaseYear: 1981, isListened: false)
        ]

        let result = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: nil,
            filterMood: nil,
            statusFilter: .open,
            sortOrder: .number
        )

        XCTAssertEqual(result.map(\.title), ["Offen"])
    }

    func testMoodFilterMatchesEquivalentMoodByName() {
        let assignedMood = Mood(name: "Gruselig", iconName: "😱")
        let selectedMood = Mood(name: "Gruselig", iconName: "😱")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, moods: [assignedMood]),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981)
        ]

        let result = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: nil,
            filterMood: selectedMood,
            statusFilter: .all,
            sortOrder: .number
        )

        XCTAssertEqual(result.map(\.title), ["A"])
    }

    func testGroupSummaryCountsListenedAndOpenEpisodes() {
        let group = EpisodeListGroup(
            id: "test",
            title: "Test",
            episodes: [
                Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1980, isListened: true),
                Episode(episodeNumber: 2, title: "Offen", releaseYear: 1981, isListened: false),
                Episode(episodeNumber: 3, title: "Auch offen", releaseYear: 1982, isListened: false)
            ],
            progressTotalOverride: nil
        )

        XCTAssertEqual(group.listenedCount, 1)
        XCTAssertEqual(group.openCount, 2)
        XCTAssertEqual(group.summary, "1 von 3 gehört · 2 offen")
        XCTAssertEqual(group.progress, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testUniverseGroupsCanUseCatalogTotalForProgress() {
        let universe = Universe(name: "Die drei ???")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, isListened: true, universe: universe),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981, isListened: true, universe: universe),
            Episode(episodeNumber: 3, title: "C", releaseYear: 1982, isListened: false, universe: universe)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2,
            catalogTotalsByUniverse: ["die drei ???": 7],
            preferCatalogTotals: true
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].summary, "2 von 7 gehört · 5 offen")
        XCTAssertEqual(groups[0].progress, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testAvailableMoodsAndMoodEpisodesMatchByNameWhenInstancesDiffer() {
        let libraryMood = Mood(name: "Gruselig", iconName: "😱")
        let pickerMood = Mood(name: "Gruselig", iconName: "😱")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, moods: [libraryMood]),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981, moods: [libraryMood], isListened: true)
        ]

        let available = SmartListDefinition.availableMoods(
            from: episodes,
            filter: .all,
            allMoods: [pickerMood]
        )
        let matching = SmartListDefinition.episodesForMood(
            pickerMood,
            from: episodes,
            filter: .all,
            count: 10
        )

        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available.first?.count, 2)
        XCTAssertEqual(matching.count, 2)
    }

    func testCollapseStoreRoundTripsScopedState() {
        let state: [String: Set<String>] = [
            "Nummer|__all__|Alle|multi": ["universe:Die drei ???", "universe:TKKG"],
            "Bewertung|__all__|Alle|multi": ["rating:5"]
        ]

        let encoded = EpisodeGroupCollapseStore.encode(state)
        let decoded = EpisodeGroupCollapseStore.decode(encoded)

        XCTAssertEqual(decoded["Nummer|__all__|Alle|multi"] ?? [], ["universe:Die drei ???", "universe:TKKG"])
        XCTAssertEqual(decoded["Bewertung|__all__|Alle|multi"] ?? [], ["rating:5"])
    }

    func testCollapseStoreScopeKeySeparatesDifferentContexts() {
        let byNumber = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Nummer",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )
        let byRating = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Bewertung",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )

        XCTAssertNotEqual(byNumber, byRating)
    }

    func testCollapseStoreCanToggleGroupInScopedRawValue() {
        let scopeKey = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Nummer",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )

        let encoded = EpisodeGroupCollapseStore.toggle(
            groupID: "universe:Die drei ???",
            in: "",
            scopeKey: scopeKey
        )
        let collapsed = EpisodeGroupCollapseStore.collapsedIDs(from: encoded, scopeKey: scopeKey)

        XCTAssertEqual(collapsed, ["universe:Die drei ???"])
    }

    func testEpisodeDeleteStateBuildsSingleEpisodeConfirmation() {
        var deleteState = EpisodeDeleteState()
        let episode = Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979)

        deleteState.request(episode)

        XCTAssertTrue(deleteState.isActive)
        XCTAssertEqual(deleteState.title, "Folge löschen?")
        XCTAssertTrue(deleteState.message.contains("Super-Papagei"))
    }

    func testEpisodeDeleteStateCanCollectMultipleEpisodesFromOffsets() {
        var deleteState = EpisodeDeleteState()
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1980),
            Episode(episodeNumber: 3, title: "C", releaseYear: 1981)
        ]

        deleteState.request(from: episodes, at: IndexSet([0, 2]))

        XCTAssertEqual(deleteState.pendingEpisodes.map(\.title), ["A", "C"])
        XCTAssertEqual(deleteState.title, "2 Folgen löschen?")
    }

    func testStatisticsOverviewPreferencesRestoreDefaultOrderWhenEmpty() {
        let sections = StatisticsOverviewPreferences.orderedItems(
            from: "",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(sections, StatisticsOverviewKind.allCases)
    }

    func testStatisticsOverviewPreferencesKeepSavedOrderAndAppendMissingItems() {
        let sections = StatisticsOverviewPreferences.orderedItems(
            from: "averageRating,episodes",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(sections, [.averageRating, .episodes, .listened, .open, .totalListens])
    }

    func testStatisticsOverviewPreferencesDecodeHiddenItems() {
        let hidden = StatisticsOverviewPreferences.hiddenItems(
            from: "episodes,averageRating",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(hidden, [.episodes, .averageRating])
    }

    @MainActor
    func testSyncPreparationDeduplicatesReferenceDataBySyncKey() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let keeperUniverse = Universe(name: "Die drei ???")
        let duplicateUniverse = Universe(name: "Die drei ???", syncKey: "universe:die drei ???")
        let keeperMood = Mood(name: "Gruselig", iconName: "😱")
        let duplicateMood = Mood(name: "Gruselig", iconName: nil, syncKey: "mood:gruselig")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: duplicateUniverse,
            moods: [duplicateMood]
        )

        context.insert(keeperUniverse)
        context.insert(duplicateUniverse)
        context.insert(keeperMood)
        context.insert(duplicateMood)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].universe?.resolvedSyncKey, "universe:die drei ???")
        XCTAssertEqual(episodes[0].moods.map(\.resolvedSyncKey), ["mood:gruselig"])
        XCTAssertEqual(episodes[0].resolvedSyncKey, "episode:universe:die drei ???#1")
    }

    @MainActor
    func testBootstrapperProvidesDefaultUniverseWhenMissing() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )

        let universe = AppDataBootstrapper.ensureDefaultUniverse(in: container.mainContext)

        XCTAssertEqual(universe?.name, "Allgemein")
        XCTAssertEqual(universe?.resolvedSyncKey, "universe:allgemein")
    }

    func testEpisodeListControlsDetectActiveFiltersAndCanResetThem() {
        let mood = Mood(name: "Gruselig", iconName: "😱")
        let universe = Universe(name: "Die drei ???")
        var controls = EpisodeListControlsState(
            searchText: "Papagei",
            filterMood: mood,
            filterUniverse: universe,
            statusFilter: .rated,
            sortOrder: .title
        )

        XCTAssertTrue(controls.hasActiveFilter)

        controls.resetFilters()

        XCTAssertNil(controls.filterMood)
        XCTAssertNil(controls.filterUniverse)
        XCTAssertEqual(controls.statusFilter, .all)
        XCTAssertEqual(controls.searchText, "Papagei")
        XCTAssertEqual(controls.sortOrder, .title)
    }

    func testEpisodeListControlsCanKeepMoodFilterWhenResettingForIPad() {
        let mood = Mood(name: "Abenteuer", iconName: "🧭")
        var controls = EpisodeListControlsState(filterMood: mood, statusFilter: .listened)

        controls.resetFilters(resetMood: false)

        XCTAssertEqual(controls.filterMood?.name, "Abenteuer")
        XCTAssertEqual(controls.statusFilter, .all)
    }

    func testSplitLayoutDeciderUsesRegularSizeClassEvenBelowThreshold() {
        XCTAssertTrue(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .regular,
                width: 700
            )
        )
    }

    func testSplitLayoutDeciderUsesWidthThresholdForCompactSizeClass() {
        XCTAssertFalse(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .compact,
                width: 760
            )
        )

        XCTAssertTrue(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .compact,
                width: 800
            )
        )
    }

    func testStatisticsRegularLayoutUsesSingleDetailColumnForPortraitLikeWidths() {
        let layout = StatisticsRegularLayout(containerWidth: 820)

        XCTAssertEqual(layout.detailColumns.count, 1)
        XCTAssertLessThanOrEqual(layout.contentWidth, 760)
        XCTAssertGreaterThanOrEqual(layout.horizontalPadding, 24)
    }

    func testStatisticsRegularLayoutUsesTwoDetailColumnsForWideWidths() {
        let layout = StatisticsRegularLayout(containerWidth: 1180)

        XCTAssertEqual(layout.detailColumns.count, 2)
        XCTAssertLessThanOrEqual(layout.contentWidth, 1100)
        XCTAssertGreaterThan(layout.horizontalPadding, 24)
    }
}
