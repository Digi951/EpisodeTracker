# "Als naechstes hoeren" — Smart Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth tab "Als naechstes" with six curated Smart Lists that answer "What should I listen to next?"

**Architecture:** A `SmartListDefinition` enum holds metadata (icon, name, empty-state text) and static query methods that operate on plain `[Episode]` arrays — no SwiftData queries in the logic layer, making everything unit-testable. Three new views (`UpNextView`, `SmartListDetailView`, `MoodPickerView`) handle presentation. A `SmartListNavigation` enum handles push navigation within the tab. `ContentView` gets a fourth tab for both iPhone and iPad.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `EpisodeTracker/SmartListDefinition.swift` | Enum with 6 cases, display metadata, static query methods |
| `EpisodeTracker/SmartListNavigation.swift` | Navigation enum for push destinations within the Up Next tab |
| `EpisodeTracker/UpNextView.swift` | Smart List overview (Level 1) — the tab's root view |
| `EpisodeTracker/SmartListDetailView.swift` | Episode list for a selected Smart List (Level 2) |
| `EpisodeTracker/MoodPickerView.swift` | Mood selection for "Zufaellig nach Stimmung" (Level 1.5) |
| `EpisodeTrackerTests/SmartListTests.swift` | Unit tests for all query logic |

### Modified files

| File | Change |
|------|--------|
| `EpisodeTracker/ContentView.swift` | Add fourth tab with `UpNextView` (iPhone) and `UpNextSplitView` (iPad) |

---

### Task 1: SmartListDefinition Enum + SmartListNavigation

**Files:**
- Create: `EpisodeTracker/SmartListDefinition.swift`
- Create: `EpisodeTracker/SmartListNavigation.swift`

- [ ] **Step 1: Create SmartListDefinition with metadata**

```swift
// EpisodeTracker/SmartListDefinition.swift
import Foundation

enum SmartListDefinition: String, CaseIterable, Identifiable, Hashable {
    case fortsetzen
    case langeNichtGehoert
    case uebersprungen
    case topBewertet
    case zufaellig
    case zufaelligNachStimmung

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fortsetzen: "▶️"
        case .langeNichtGehoert: "⏸️"
        case .uebersprungen: "⏭️"
        case .topBewertet: "⭐"
        case .zufaellig: "🎲"
        case .zufaelligNachStimmung: "😱"
        }
    }

    var displayName: String {
        switch self {
        case .fortsetzen: "Fortsetzen"
        case .langeNichtGehoert: "Lange nicht gehört"
        case .uebersprungen: "Übersprungen"
        case .topBewertet: "Top bewertet"
        case .zufaellig: "Zufällig"
        case .zufaelligNachStimmung: "Zufällig nach Stimmung"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .fortsetzen: "Du bist überall auf dem neuesten Stand"
        case .langeNichtGehoert: "Keine lang pausierten Serien"
        case .uebersprungen: "Keine übersprungenen Folgen"
        case .topBewertet: "Keine bewerteten ungehörten Folgen"
        case .zufaellig: "Alles gehört!"
        case .zufaelligNachStimmung: "Keine Stimmungen mit offenen Folgen"
        }
    }

    /// Whether this smart list uses random shuffling (supports "Neu wuerfeln").
    var isRandomList: Bool {
        self == .zufaellig || self == .zufaelligNachStimmung
    }

    /// Threshold in days for "Lange nicht gehoert".
    static let longPauseDays: Int = 30

    // MARK: - Query Dispatch

    /// Returns episodes for this smart list.
    /// For `.zufaelligNachStimmung`, returns empty — use `episodesForMood(_:from:)` instead.
    func episodes(from allEpisodes: [Episode], referenceDate: Date = .now) -> [Episode] {
        switch self {
        case .fortsetzen:
            return Self.continuationEpisodes(from: allEpisodes)
        case .langeNichtGehoert:
            return Self.longPauseEpisodes(from: allEpisodes, referenceDate: referenceDate)
        case .uebersprungen:
            return Self.skippedEpisodes(from: allEpisodes)
        case .topBewertet:
            return Self.topRatedEpisodes(from: allEpisodes)
        case .zufaellig:
            return Self.randomEpisodes(from: allEpisodes)
        case .zufaelligNachStimmung:
            return []
        }
    }

    // MARK: - Query Logic (stubs — implemented in Tasks 2-4)

    static func continuationEpisodes(from episodes: [Episode]) -> [Episode] {
        []
    }

    static func skippedEpisodes(from episodes: [Episode]) -> [Episode] {
        []
    }

    static func longPauseEpisodes(from episodes: [Episode], referenceDate: Date = .now) -> [Episode] {
        []
    }

    static func topRatedEpisodes(from episodes: [Episode]) -> [Episode] {
        []
    }

    static func randomEpisodes(from episodes: [Episode], count: Int = 10) -> [Episode] {
        []
    }

    static func episodesForMood(_ mood: Mood, from episodes: [Episode], count: Int = 10) -> [Episode] {
        []
    }

    static func availableMoods(from episodes: [Episode], allMoods: [Mood]) -> [(mood: Mood, count: Int)] {
        []
    }

    // MARK: - Teaser

    static func teaserText(for episode: Episode) -> String {
        let universeName = episode.universe?.name ?? "Allgemein"
        return "\(universeName): Folge \(episode.episodeNumber) — \(episode.title)"
    }
}
```

- [ ] **Step 2: Create SmartListNavigation**

```swift
// EpisodeTracker/SmartListNavigation.swift
import Foundation

enum SmartListNavigation: Hashable {
    case detail(SmartListDefinition)
    case moodPicker
    case moodDetail(Mood)
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add EpisodeTracker/SmartListDefinition.swift EpisodeTracker/SmartListNavigation.swift
git commit -m "feat: add SmartListDefinition enum and SmartListNavigation with metadata stubs"
```

---

### Task 2: Fortsetzen + Uebersprungen Query Logic (TDD)

**Files:**
- Create: `EpisodeTrackerTests/SmartListTests.swift`
- Modify: `EpisodeTracker/SmartListDefinition.swift`

These two queries share the same per-universe pattern: group episodes by universe, find the highest listened number, then return either the next continuation or the gaps.

- [ ] **Step 1: Write failing tests for continuationEpisodes**

```swift
// EpisodeTrackerTests/SmartListTests.swift
import XCTest
@testable import EpisodeTracker

final class SmartListTests: XCTestCase {

    // MARK: - Helpers

    private func makeUniverse(_ name: String) -> Universe {
        Universe(name: name)
    }

    private func makeEpisode(
        number: Int,
        title: String = "Folge",
        universe: Universe? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int? = nil,
        lastListenedAt: Date? = nil,
        moods: [Mood] = []
    ) -> Episode {
        Episode(
            episodeNumber: number,
            title: title,
            releaseYear: 2020,
            isListened: isListened,
            rating: rating,
            listenCount: listenCount ?? (isListened ? 1 : 0),
            lastListenedAt: lastListenedAt,
            universe: universe,
            moods: moods
        )
    }

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    // MARK: - Fortsetzen (Continue)

    func testContinuationReturnsNextEpisodePerUniverse() {
        let u1 = makeUniverse("Die drei ???")
        let u2 = makeUniverse("TKKG")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 3, universe: u1),
            makeEpisode(number: 4, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(5)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        // u1 was active more recently (1 day ago) => first
        XCTAssertEqual(result[0].episodeNumber, 3)
        XCTAssertEqual(result[0].universe?.name, "Die drei ???")
        // u2 was active 5 days ago => second
        XCTAssertEqual(result[1].episodeNumber, 2)
        XCTAssertEqual(result[1].universe?.name, "TKKG")
    }

    func testContinuationSkipsUniverseWithNoListenedEpisodes() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1),
            makeEpisode(number: 2, universe: u1),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    func testContinuationSkipsUniverseFullyListened() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    func testContinuationHandlesGapsInEpisodeNumbers() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
            // No episode 3
            makeEpisode(number: 5, universe: u1),
            makeEpisode(number: 10, universe: u1),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].episodeNumber, 5)
    }

    func testContinuationSortsByMostRecentActivity() {
        let u1 = makeUniverse("Old")
        let u2 = makeUniverse("Recent")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(30)),
            makeEpisode(number: 2, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].universe?.name, "Recent")
        XCTAssertEqual(result[1].universe?.name, "Old")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests 2>&1 | grep -E '(Test Case|TEST|FAIL|PASS|error:)' | head -20`
Expected: 4 test failures (methods return `[]`)

- [ ] **Step 3: Implement continuationEpisodes**

Replace the stub in `EpisodeTracker/SmartListDefinition.swift`:

```swift
static func continuationEpisodes(from episodes: [Episode]) -> [Episode] {
    let withUniverse = episodes.filter { $0.universe != nil }
    let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

    var results: [(episode: Episode, lastActivity: Date)] = []

    for (_, universeEpisodes) in grouped {
        let listened = universeEpisodes.filter(\.isListened)
        guard !listened.isEmpty else { continue }

        let maxListenedNumber = listened.map(\.episodeNumber).max()!

        let nextUnlistened = universeEpisodes
            .filter { $0.episodeNumber > maxListenedNumber && !$0.isListened }
            .min(by: { $0.episodeNumber < $1.episodeNumber })

        if let next = nextUnlistened {
            let lastActivity = listened.compactMap(\.lastListenedAt).max() ?? .distantPast
            results.append((next, lastActivity))
        }
    }

    results.sort { $0.lastActivity > $1.lastActivity }
    return results.map(\.episode)
}
```

- [ ] **Step 4: Run continuation tests to verify they pass**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests 2>&1 | grep -E '(Test Case|FAIL|PASS)' | head -20`
Expected: All 4 continuation tests PASS

- [ ] **Step 5: Write failing tests for skippedEpisodes**

Add to `SmartListTests.swift`:

```swift
// MARK: - Uebersprungen (Skipped)

func testSkippedFindsGapsBelowMaxListened() {
    let u1 = makeUniverse("Die drei ???")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true),
        makeEpisode(number: 2, universe: u1),            // skipped
        makeEpisode(number: 3, universe: u1),            // skipped
        makeEpisode(number: 4, universe: u1, isListened: true),
        makeEpisode(number: 5, universe: u1),            // NOT skipped (above max)
    ]

    let result = SmartListDefinition.skippedEpisodes(from: episodes)

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].episodeNumber, 2)
    XCTAssertEqual(result[1].episodeNumber, 3)
}

func testSkippedAcrossMultipleUniversesSortedByNameThenNumber() {
    let tkkg = makeUniverse("TKKG")
    let ddf = makeUniverse("Die drei ???")
    let episodes = [
        makeEpisode(number: 1, universe: ddf, isListened: true),
        makeEpisode(number: 2, universe: ddf),            // skipped
        makeEpisode(number: 3, universe: ddf, isListened: true),
        makeEpisode(number: 1, universe: tkkg, isListened: true),
        makeEpisode(number: 2, universe: tkkg),           // skipped
        makeEpisode(number: 3, universe: tkkg, isListened: true),
    ]

    let result = SmartListDefinition.skippedEpisodes(from: episodes)

    XCTAssertEqual(result.count, 2)
    // "Die drei ???" sorts before "TKKG"
    XCTAssertEqual(result[0].universe?.name, "Die drei ???")
    XCTAssertEqual(result[0].episodeNumber, 2)
    XCTAssertEqual(result[1].universe?.name, "TKKG")
    XCTAssertEqual(result[1].episodeNumber, 2)
}

func testSkippedReturnsEmptyWhenNoGaps() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true),
        makeEpisode(number: 2, universe: u1, isListened: true),
        makeEpisode(number: 3, universe: u1),
    ]

    let result = SmartListDefinition.skippedEpisodes(from: episodes)

    XCTAssertTrue(result.isEmpty)
}
```

- [ ] **Step 6: Run skipped tests to verify they fail**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests/testSkippedFindsGapsBelowMaxListened -only-testing:EpisodeTrackerTests/SmartListTests/testSkippedAcrossMultipleUniversesSortedByNameThenNumber -only-testing:EpisodeTrackerTests/SmartListTests/testSkippedReturnsEmptyWhenNoGaps 2>&1 | grep -E '(FAIL|PASS)' | head -10`
Expected: 3 FAILs

- [ ] **Step 7: Implement skippedEpisodes**

Replace the stub in `SmartListDefinition.swift`:

```swift
static func skippedEpisodes(from episodes: [Episode]) -> [Episode] {
    let withUniverse = episodes.filter { $0.universe != nil }
    let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

    var results: [(universeName: String, episode: Episode)] = []

    for (_, universeEpisodes) in grouped {
        let listened = universeEpisodes.filter(\.isListened)
        guard !listened.isEmpty else { continue }

        let maxListenedNumber = listened.map(\.episodeNumber).max()!

        let skipped = universeEpisodes.filter {
            $0.episodeNumber < maxListenedNumber && !$0.isListened
        }

        for episode in skipped {
            let name = episode.universe?.name ?? ""
            results.append((name, episode))
        }
    }

    results.sort {
        if $0.universeName != $1.universeName {
            return $0.universeName.localizedCompare($1.universeName) == .orderedAscending
        }
        return $0.episode.episodeNumber < $1.episode.episodeNumber
    }

    return results.map(\.episode)
}
```

- [ ] **Step 8: Run all SmartListTests to verify they pass**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests 2>&1 | grep -E '(Test Case|FAIL|PASS|Executed)' | head -20`
Expected: All 7 tests PASS

- [ ] **Step 9: Commit**

```bash
git add EpisodeTrackerTests/SmartListTests.swift EpisodeTracker/SmartListDefinition.swift
git commit -m "feat: implement Fortsetzen and Uebersprungen query logic with tests"
```

---

### Task 3: Lange nicht gehoert + Top bewertet Query Logic (TDD)

**Files:**
- Modify: `EpisodeTrackerTests/SmartListTests.swift`
- Modify: `EpisodeTracker/SmartListDefinition.swift`

- [ ] **Step 1: Write failing tests for longPauseEpisodes**

Add to `SmartListTests.swift`:

```swift
// MARK: - Lange nicht gehoert (Long Pause)

func testLongPauseFindsUniversesPausedOverThreshold() {
    let u1 = makeUniverse("Paused")
    let u2 = makeUniverse("Active")
    let referenceDate = Date()
    let episodes = [
        // u1: last listened 60 days ago — qualifies
        makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(60)),
        makeEpisode(number: 2, universe: u1),
        // u2: last listened 5 days ago — does NOT qualify
        makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(5)),
        makeEpisode(number: 2, universe: u2),
    ]

    let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].universe?.name, "Paused")
    XCTAssertEqual(result[0].episodeNumber, 2)
}

func testLongPauseSortsByLongestPauseFirst() {
    let u1 = makeUniverse("Short Pause")
    let u2 = makeUniverse("Long Pause")
    let referenceDate = Date()
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(35)),
        makeEpisode(number: 2, universe: u1),
        makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(90)),
        makeEpisode(number: 2, universe: u2),
    ]

    let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].universe?.name, "Long Pause")
    XCTAssertEqual(result[1].universe?.name, "Short Pause")
}

func testLongPauseExcludesFullyListenedUniverses() {
    let u1 = makeUniverse("Done")
    let referenceDate = Date()
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(60)),
        makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(60)),
    ]

    let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

    XCTAssertTrue(result.isEmpty)
}

func testLongPauseUsesThresholdBoundary() {
    let u1 = makeUniverse("Exactly30")
    let referenceDate = Date()
    let episodes = [
        // Exactly 30 days — should NOT qualify (needs > 30)
        makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(30)),
        makeEpisode(number: 2, universe: u1),
    ]

    let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

    XCTAssertTrue(result.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseFindsUniversesPausedOverThreshold -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseSortsByLongestPauseFirst 2>&1 | grep -E '(FAIL|PASS)' | head -10`
Expected: FAILs

- [ ] **Step 3: Implement longPauseEpisodes**

Replace the stub in `SmartListDefinition.swift`:

```swift
static func longPauseEpisodes(from episodes: [Episode], referenceDate: Date = .now) -> [Episode] {
    let withUniverse = episodes.filter { $0.universe != nil }
    let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

    let thresholdDate = Calendar.current.date(
        byAdding: .day, value: -longPauseDays, to: referenceDate
    )!

    var results: [(episode: Episode, lastActivity: Date)] = []

    for (_, universeEpisodes) in grouped {
        let listened = universeEpisodes.filter(\.isListened)
        guard !listened.isEmpty else { continue }

        let hasUnlistened = universeEpisodes.contains { !$0.isListened }
        guard hasUnlistened else { continue }

        let lastActivity = listened.compactMap(\.lastListenedAt).max() ?? .distantPast
        guard lastActivity < thresholdDate else { continue }

        // Find next continuation episode for this universe
        let maxListenedNumber = listened.map(\.episodeNumber).max()!
        let nextUnlistened = universeEpisodes
            .filter { $0.episodeNumber > maxListenedNumber && !$0.isListened }
            .min(by: { $0.episodeNumber < $1.episodeNumber })

        if let next = nextUnlistened {
            results.append((next, lastActivity))
        }
    }

    // Sort by longest pause first (oldest lastActivity first)
    results.sort { $0.lastActivity < $1.lastActivity }
    return results.map(\.episode)
}
```

- [ ] **Step 4: Run long-pause tests to verify they pass**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseFindsUniversesPausedOverThreshold -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseSortsByLongestPauseFirst -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseExcludesFullyListenedUniverses -only-testing:EpisodeTrackerTests/SmartListTests/testLongPauseUsesThresholdBoundary 2>&1 | grep -E '(FAIL|PASS)' | head -10`
Expected: All 4 PASS

- [ ] **Step 5: Write failing tests for topRatedEpisodes**

Add to `SmartListTests.swift`:

```swift
// MARK: - Top bewertet (Top Rated)

func testTopRatedReturnsOnlyUnlistenedWithRating() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: false, rating: 5),
        makeEpisode(number: 2, universe: u1, isListened: true, rating: 5),  // listened — excluded
        makeEpisode(number: 3, universe: u1, isListened: false),            // no rating — excluded
        makeEpisode(number: 4, universe: u1, isListened: false, rating: 3),
    ]

    let result = SmartListDefinition.topRatedEpisodes(from: episodes)

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].episodeNumber, 1) // rating 5
    XCTAssertEqual(result[1].episodeNumber, 4) // rating 3
}

func testTopRatedSortsByRatingDescendingThenNumberAscending() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 10, universe: u1, isListened: false, rating: 4),
        makeEpisode(number: 5, universe: u1, isListened: false, rating: 4),
        makeEpisode(number: 1, universe: u1, isListened: false, rating: 5),
    ]

    let result = SmartListDefinition.topRatedEpisodes(from: episodes)

    XCTAssertEqual(result.count, 3)
    XCTAssertEqual(result[0].episodeNumber, 1)  // rating 5
    XCTAssertEqual(result[1].episodeNumber, 5)  // rating 4, lower number
    XCTAssertEqual(result[2].episodeNumber, 10) // rating 4, higher number
}

func testTopRatedReturnsEmptyWhenNoRatedUnlistened() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true, rating: 5),
        makeEpisode(number: 2, universe: u1, isListened: false),
    ]

    let result = SmartListDefinition.topRatedEpisodes(from: episodes)

    XCTAssertTrue(result.isEmpty)
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests/testTopRatedReturnsOnlyUnlistenedWithRating 2>&1 | grep -E '(FAIL|PASS)' | head -5`
Expected: FAIL

- [ ] **Step 7: Implement topRatedEpisodes**

Replace the stub in `SmartListDefinition.swift`:

```swift
static func topRatedEpisodes(from episodes: [Episode]) -> [Episode] {
    episodes
        .filter { !$0.isListened && $0.rating != nil }
        .sorted {
            if $0.rating! != $1.rating! {
                return $0.rating! > $1.rating!
            }
            return $0.episodeNumber < $1.episodeNumber
        }
}
```

- [ ] **Step 8: Run all SmartListTests to verify they pass**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests 2>&1 | grep -E '(Executed|FAIL)' | head -5`
Expected: `Executed 14 tests, with 0 failures`

- [ ] **Step 9: Commit**

```bash
git add EpisodeTrackerTests/SmartListTests.swift EpisodeTracker/SmartListDefinition.swift
git commit -m "feat: implement Lange nicht gehoert and Top bewertet query logic with tests"
```

---

### Task 4: Zufaellig + Mood Queries (TDD)

**Files:**
- Modify: `EpisodeTrackerTests/SmartListTests.swift`
- Modify: `EpisodeTracker/SmartListDefinition.swift`

- [ ] **Step 1: Write failing tests for randomEpisodes, episodesForMood, and availableMoods**

Add to `SmartListTests.swift`:

```swift
// MARK: - Zufaellig (Random)

func testRandomReturnsOnlyUnlistenedEpisodes() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true),
        makeEpisode(number: 2, universe: u1),
        makeEpisode(number: 3, universe: u1),
        makeEpisode(number: 4, universe: u1, isListened: true),
        makeEpisode(number: 5, universe: u1),
    ]

    let result = SmartListDefinition.randomEpisodes(from: episodes)

    XCTAssertEqual(result.count, 3)
    for episode in result {
        XCTAssertFalse(episode.isListened)
    }
}

func testRandomRespectsCountLimit() {
    let u1 = makeUniverse("Test")
    var episodes: [Episode] = []
    for i in 1...20 {
        episodes.append(makeEpisode(number: i, universe: u1))
    }

    let result = SmartListDefinition.randomEpisodes(from: episodes, count: 5)

    XCTAssertEqual(result.count, 5)
}

func testRandomReturnsAllWhenFewerThanCount() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1),
        makeEpisode(number: 2, universe: u1),
    ]

    let result = SmartListDefinition.randomEpisodes(from: episodes, count: 10)

    XCTAssertEqual(result.count, 2)
}

func testRandomReturnsEmptyWhenAllListened() {
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true),
        makeEpisode(number: 2, universe: u1, isListened: true),
    ]

    let result = SmartListDefinition.randomEpisodes(from: episodes)

    XCTAssertTrue(result.isEmpty)
}

// MARK: - Zufaellig nach Stimmung (Random by Mood)

func testEpisodesForMoodReturnsOnlyMatchingUnlistened() {
    let mood1 = Mood(name: "Gruselig", iconName: "😱")
    let mood2 = Mood(name: "Witzig", iconName: "😄")
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, moods: [mood1]),           // matches
        makeEpisode(number: 2, universe: u1, isListened: true, moods: [mood1]), // listened
        makeEpisode(number: 3, universe: u1, moods: [mood2]),           // wrong mood
        makeEpisode(number: 4, universe: u1, moods: [mood1, mood2]),    // matches
        makeEpisode(number: 5, universe: u1),                           // no mood
    ]

    let result = SmartListDefinition.episodesForMood(mood1, from: episodes)

    XCTAssertEqual(result.count, 2)
    for episode in result {
        XCTAssertFalse(episode.isListened)
        XCTAssertTrue(episode.moods.contains(where: { $0 === mood1 }))
    }
}

func testEpisodesForMoodRespectsCountLimit() {
    let mood = Mood(name: "Test", iconName: "🧪")
    let u1 = makeUniverse("Test")
    var episodes: [Episode] = []
    for i in 1...20 {
        episodes.append(makeEpisode(number: i, universe: u1, moods: [mood]))
    }

    let result = SmartListDefinition.episodesForMood(mood, from: episodes, count: 5)

    XCTAssertEqual(result.count, 5)
}

// MARK: - Available Moods

func testAvailableMoodsReturnsOnlyMoodsWithUnlistenedEpisodes() {
    let mood1 = Mood(name: "Gruselig", iconName: "😱")
    let mood2 = Mood(name: "Witzig", iconName: "😄")
    let mood3 = Mood(name: "Leer", iconName: "🫥")
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, moods: [mood1]),
        makeEpisode(number: 2, universe: u1, moods: [mood1]),
        makeEpisode(number: 3, universe: u1, moods: [mood2]),
        makeEpisode(number: 4, universe: u1, isListened: true, moods: [mood3]),
    ]

    let result = SmartListDefinition.availableMoods(from: episodes, allMoods: [mood1, mood2, mood3])

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[0].mood.name, "Gruselig")
    XCTAssertEqual(result[0].count, 2)
    XCTAssertEqual(result[1].mood.name, "Witzig")
    XCTAssertEqual(result[1].count, 1)
}

func testAvailableMoodsReturnsEmptyWhenNoUnlistenedWithMoods() {
    let mood1 = Mood(name: "Test", iconName: "🧪")
    let u1 = makeUniverse("Test")
    let episodes = [
        makeEpisode(number: 1, universe: u1, isListened: true, moods: [mood1]),
        makeEpisode(number: 2, universe: u1),
    ]

    let result = SmartListDefinition.availableMoods(from: episodes, allMoods: [mood1])

    XCTAssertTrue(result.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests/testRandomReturnsOnlyUnlistenedEpisodes -only-testing:EpisodeTrackerTests/SmartListTests/testEpisodesForMoodReturnsOnlyMatchingUnlistened -only-testing:EpisodeTrackerTests/SmartListTests/testAvailableMoodsReturnsOnlyMoodsWithUnlistenedEpisodes 2>&1 | grep -E '(FAIL|PASS)' | head -10`
Expected: 3 FAILs

- [ ] **Step 3: Implement randomEpisodes, episodesForMood, and availableMoods**

Replace the three stubs in `SmartListDefinition.swift`:

```swift
static func randomEpisodes(from episodes: [Episode], count: Int = 10) -> [Episode] {
    let unlistened = episodes.filter { !$0.isListened }
    return Array(unlistened.shuffled().prefix(count))
}

static func episodesForMood(_ mood: Mood, from episodes: [Episode], count: Int = 10) -> [Episode] {
    let matching = episodes.filter { !$0.isListened && $0.moods.contains(where: { $0 === mood }) }
    return Array(matching.shuffled().prefix(count))
}

static func availableMoods(from episodes: [Episode], allMoods: [Mood]) -> [(mood: Mood, count: Int)] {
    let unlistened = episodes.filter { !$0.isListened }
    var results: [(mood: Mood, count: Int)] = []

    for mood in allMoods {
        let count = unlistened.filter { $0.moods.contains(where: { $0 === mood }) }.count
        if count > 0 {
            results.append((mood, count))
        }
    }

    results.sort { $0.mood.name.localizedCompare($1.mood.name) == .orderedAscending }
    return results
}
```

- [ ] **Step 4: Run all SmartListTests to verify they pass**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:EpisodeTrackerTests/SmartListTests 2>&1 | grep -E '(Executed|FAIL)' | head -5`
Expected: `Executed 22 tests, with 0 failures`

- [ ] **Step 5: Also run existing tests to ensure nothing is broken**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(Executed|FAIL)' | head -5`
Expected: All tests pass (22 new + 5 existing = 27 total)

- [ ] **Step 6: Commit**

```bash
git add EpisodeTrackerTests/SmartListTests.swift EpisodeTracker/SmartListDefinition.swift
git commit -m "feat: implement Zufaellig and mood-based query logic with tests"
```

---

### Task 5: UpNextView — Smart List Overview

**Files:**
- Create: `EpisodeTracker/UpNextView.swift`

- [ ] **Step 1: Create UpNextView**

```swift
// EpisodeTracker/UpNextView.swift
import SwiftUI
import SwiftData

struct UpNextView: View {
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]

    var body: some View {
        List {
            ForEach(SmartListDefinition.allCases) { smartList in
                smartListRow(smartList)
            }
        }
    }

    @ViewBuilder
    private func smartListRow(_ smartList: SmartListDefinition) -> some View {
        switch smartList {
        case .zufaelligNachStimmung:
            NavigationLink(value: SmartListNavigation.moodPicker) {
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: "Stimmung wählen..."
                )
            }
        default:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                let firstEpisode = smartList.episodes(from: episodes).first
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: firstEpisode.map { SmartListDefinition.teaserText(for: $0) },
                    emptyText: smartList.emptyStateMessage
                )
            }
        }
    }
}

private struct SmartListRowContent: View {
    let icon: String
    let name: String
    var teaser: String?
    var emptyText: String = "Keine Vorschläge"

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))

                Text(teaser ?? emptyText)
                    .font(.caption)
                    .foregroundStyle(teaser != nil ? .secondary : .tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EpisodeTracker/UpNextView.swift
git commit -m "feat: add UpNextView with smart list overview and teasers"
```

---

### Task 6: SmartListDetailView — Episode List

**Files:**
- Create: `EpisodeTracker/SmartListDetailView.swift`

The detail view shows episodes from a smart list using the existing `EpisodeRowView`. For random lists, a "Neu wuerfeln" toolbar button reshuffles the selection. The view supports both iPhone (push navigation via NavigationLink) and iPad (selection binding drives detail column).

- [ ] **Step 1: Create SmartListDetailView**

```swift
// EpisodeTracker/SmartListDetailView.swift
import SwiftUI
import SwiftData

struct SmartListDetailView: View {
    let smartList: SmartListDefinition
    var mood: Mood?
    var iPadSelection: Binding<Episode?>?

    @Query private var allEpisodes: [Episode]
    @State private var shuffledEpisodes: [Episode]?

    private var displayedEpisodes: [Episode] {
        if smartList.isRandomList {
            return shuffledEpisodes ?? []
        }
        return smartList.episodes(from: allEpisodes)
    }

    private var navigationTitle: String {
        if smartList == .zufaelligNachStimmung, let mood {
            return "\(mood.iconName ?? "") \(mood.name)"
        }
        return smartList.displayName
    }

    var body: some View {
        Group {
            if let iPadSelection {
                List(selection: iPadSelection) {
                    episodeContent
                }
            } else {
                List {
                    episodeContent
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if smartList.isRandomList {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reshuffle()
                    } label: {
                        Label("Neu würfeln", systemImage: "dice")
                    }
                }
            }
        }
        .onAppear {
            if smartList.isRandomList && shuffledEpisodes == nil {
                reshuffle()
            }
        }
    }

    @ViewBuilder
    private var episodeContent: some View {
        if displayedEpisodes.isEmpty {
            ContentUnavailableView {
                Label(smartList.displayName, systemImage: "tray")
            } description: {
                Text(smartList == .zufaelligNachStimmung
                     ? "Keine offenen Folgen mit dieser Stimmung"
                     : smartList.emptyStateMessage)
            }
            .listRowSeparator(.hidden)
        } else {
            ForEach(displayedEpisodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRowView(episode: episode)
                }
            }
        }
    }

    private func reshuffle() {
        if smartList == .zufaelligNachStimmung, let mood {
            shuffledEpisodes = SmartListDefinition.episodesForMood(mood, from: allEpisodes)
        } else if smartList == .zufaellig {
            shuffledEpisodes = SmartListDefinition.randomEpisodes(from: allEpisodes)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EpisodeTracker/SmartListDetailView.swift
git commit -m "feat: add SmartListDetailView with episode list and reshuffle button"
```

---

### Task 7: MoodPickerView

**Files:**
- Create: `EpisodeTracker/MoodPickerView.swift`

Shows all moods that have unlistened episodes. Tapping a mood navigates to `SmartListDetailView` filtered by that mood.

- [ ] **Step 1: Create MoodPickerView**

```swift
// EpisodeTracker/MoodPickerView.swift
import SwiftUI
import SwiftData

struct MoodPickerView: View {
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var allMoods: [Mood]

    private var moodsWithCounts: [(mood: Mood, count: Int)] {
        SmartListDefinition.availableMoods(from: episodes, allMoods: allMoods)
    }

    var body: some View {
        List {
            if moodsWithCounts.isEmpty {
                ContentUnavailableView {
                    Label("Keine Stimmungen", systemImage: "tray")
                } description: {
                    Text("Keine Stimmungen mit offenen Folgen")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(moodsWithCounts, id: \.mood.id) { item in
                    NavigationLink(value: SmartListNavigation.moodDetail(item.mood)) {
                        HStack(spacing: 12) {
                            Text(item.mood.iconName ?? "🎵")
                                .font(.title2)
                                .frame(width: 32)

                            Text(item.mood.name)
                                .font(.body)

                            Spacer()

                            Text("\(item.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Stimmung wählen")
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add EpisodeTracker/MoodPickerView.swift
git commit -m "feat: add MoodPickerView for mood-based random episode selection"
```

---

### Task 8: Wire Into ContentView — 4th Tab

**Files:**
- Modify: `EpisodeTracker/ContentView.swift`

Add the "Als naechstes" tab between Statistiken and Einstellungen for both iPhone and iPad. iPhone uses a `NavigationStack`; iPad uses a `NavigationSplitView` (same pattern as `EpisodeSplitView`).

- [ ] **Step 1: Add iPhone tab to iPhoneBody**

In `ContentView.swift`, add a new tab after the Statistiken tab and before the Einstellungen tab. Find this section in `iPhoneBody`:

```swift
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
            }
```

Replace with:

```swift
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            NavigationStack {
                UpNextView()
                    .navigationDestination(for: Episode.self) { episode in
                        EpisodeDetailView(episode: episode)
                    }
                    .navigationDestination(for: SmartListNavigation.self) { destination in
                        switch destination {
                        case .detail(let smartList):
                            SmartListDetailView(smartList: smartList)
                        case .moodPicker:
                            MoodPickerView()
                        case .moodDetail(let mood):
                            SmartListDetailView(smartList: .zufaelligNachStimmung, mood: mood)
                        }
                    }
                    .navigationTitle("Als nächstes")
            }
            .tabItem {
                Label("Als nächstes", systemImage: "play.circle")
            }

            NavigationStack {
                SettingsView()
            }
```

- [ ] **Step 2: Add iPad tab to iPadBody**

In `ContentView.swift`, add a new tab after the Statistiken tab in `iPadBody`. Find this section:

```swift
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
            }
```

Replace with:

```swift
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            UpNextSplitView()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
                }

            NavigationStack {
                SettingsView()
            }
```

- [ ] **Step 3: Add UpNextSplitView for iPad**

Add this struct at the bottom of `ContentView.swift`, before the `AppearanceMode` enum (after the closing brace of `IPadEpisodeListView`):

```swift
private struct UpNextSplitView: View {
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationSplitView {
            NavigationStack {
                UpNextView()
                    .navigationDestination(for: SmartListNavigation.self) { destination in
                        switch destination {
                        case .detail(let smartList):
                            SmartListDetailView(
                                smartList: smartList,
                                iPadSelection: $selectedEpisode
                            )
                        case .moodPicker:
                            MoodPickerView()
                        case .moodDetail(let mood):
                            SmartListDetailView(
                                smartList: .zufaelligNachStimmung,
                                mood: mood,
                                iPadSelection: $selectedEpisode
                            )
                        }
                    }
                    .navigationTitle("Als nächstes")
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 340, max: 380)
        } detail: {
            NavigationStack {
                if let selectedEpisode {
                    EpisodeDetailView(episode: selectedEpisode)
                } else {
                    ContentUnavailableView {
                        Label("Folge auswählen", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Wähle links eine Folge aus, um Details, Bewertung und Notizen zu sehen.")
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Run all tests to verify nothing is broken**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild test -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E '(Executed|FAIL)' | head -5`
Expected: All 27 tests pass (5 existing + 22 new)

- [ ] **Step 6: Commit**

```bash
git add EpisodeTracker/ContentView.swift
git commit -m "feat: add Als naechstes tab with Smart Lists for iPhone and iPad"
```

- [ ] **Step 7: Verify on iPad target**

Run: `cd /Users/christopherdieckmann/Projects/EpisodeTracker && xcodebuild -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

---

## Post-Implementation Notes

After all tasks are complete:

1. **Manual testing checklist:**
   - iPhone: 4 tabs visible, "Als nächstes" shows smart list overview with teasers
   - iPhone: tap each smart list → detail view shows correct episodes
   - iPhone: tap episode in detail → navigates to EpisodeDetailView
   - iPhone: "Zufällig" detail → "Neu würfeln" button reshuffles
   - iPhone: "Zufällig nach Stimmung" → mood picker → mood detail with episodes
   - iPad: same flows work with NavigationSplitView layout
   - iPad: selecting an episode in smart list detail shows it in the right column

2. **Not in scope (per spec):**
   - User-configurable thresholds
   - Freemium/Pro gating
   - Notifications or reminders
   - Persistence of random selections across app launches
