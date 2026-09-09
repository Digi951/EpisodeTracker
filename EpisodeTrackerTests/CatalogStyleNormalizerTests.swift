import XCTest
@testable import EpisodeTracker

final class CatalogStyleNormalizerTests: XCTestCase {

    private func entry(
        number: Int? = nil,
        kind: EpisodeKind = .regular,
        slug: String? = nil,
        title: String,
        releaseYear: Int = 2024
    ) -> CatalogEntry {
        CatalogEntry(
            number: number,
            kind: kind,
            slug: slug,
            title: title,
            releaseYear: releaseYear,
            collectionName: "France Culture",
            links: [:]
        )
    }

    func testAnthologyForcesEveryEntryToSpecialWithAStableSlug() {
        let input = [
            entry(number: 1, title: "Le Horla"),
            entry(number: 2, title: "La Peau de chagrin")
        ]

        let result = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")

        XCTAssertEqual(result.map(\.kind), [.special, .special])
        XCTAssertFalse(result.contains { ($0.slug ?? "").isEmpty })
        XCTAssertNotEqual(result[0].slug, result[1].slug)
    }

    func testAnthologyKeepsNumberAndLinksButRewritesKind() {
        let input = [
            CatalogEntry(
                number: 7,
                kind: .regular,
                slug: nil,
                title: "Les Misérables",
                releaseYear: 2023,
                collectionName: "France Culture",
                links: ["source": "https://radiofrance.fr/x"]
            )
        ]

        let result = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")

        XCTAssertEqual(result[0].kind, .special)
        XCTAssertEqual(result[0].number, 7)
        XCTAssertEqual(result[0].links["source"], "https://radiofrance.fr/x")
    }

    func testAnthologyNeverOverwritesAnExistingSlug() {
        let input = [entry(kind: .special, slug: "curated-slug-2019", title: "Anything")]

        let result = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")

        XCTAssertEqual(result, input)
        XCTAssertEqual(result[0].slug, "curated-slug-2019")
    }

    func testAnthologyKeepsACuratedSlugEvenOnARegularEntryWhileForcingSpecial() {
        let input = [entry(kind: .regular, slug: "curated-2020", title: "Whatever")]

        let result = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")

        XCTAssertEqual(result[0].kind, .special)
        XCTAssertEqual(result[0].slug, "curated-2020")
    }

    func testNumberedStyleLeavesEntriesUntouched() {
        let input = [
            entry(number: 1, title: "Folge 1"),
            entry(number: 2, kind: .special, slug: "s", title: "Sonderfolge")
        ]

        let result = CatalogStyleNormalizer.normalize(input, style: .numbered, collectionName: "Die drei ???")

        XCTAssertEqual(result, input)
    }

    func testNormalizationIsDeterministicAcrossRuns() {
        let input = [
            entry(number: 1, title: "Le Horla"),
            entry(number: 2, title: "La Peau de chagrin")
        ]

        let first = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")
        let second = CatalogStyleNormalizer.normalize(first, style: .anthology, collectionName: "France Culture")

        XCTAssertEqual(first, second)
    }

    func testSecondRunProducesNoDelta() {
        let raw = [
            entry(number: 1, title: "Le Horla"),
            entry(number: 2, title: "La Peau de chagrin")
        ]
        let normalized = CatalogStyleNormalizer.normalize(raw, style: .anthology, collectionName: "France Culture")

        let snapshot = CatalogSnapshot(
            catalogID: "france-culture",
            name: "France Culture",
            version: 1,
            lastUpdated: nil,
            entryCount: normalized.count,
            episodeNumbers: normalized.compactMap(\.number),
            specialSlugs: normalized.compactMap { $0.kind == .special ? $0.slug : nil }
        )

        let rerun = CatalogStyleNormalizer.normalize(raw, style: .anthology, collectionName: "France Culture")
        let rerunSnapshot = CatalogSnapshot(
            catalogID: "france-culture",
            name: "France Culture",
            version: 1,
            lastUpdated: nil,
            entryCount: rerun.count,
            episodeNumbers: rerun.compactMap(\.number),
            specialSlugs: rerun.compactMap { $0.kind == .special ? $0.slug : nil }
        )

        let delta = CatalogEpisodeDelta.make(previous: snapshot, current: rerunSnapshot, entries: rerun)
        XCTAssertNil(delta)
    }

    func testTitleOnlyEntriesStillGetDistinctSlugsViaHashFallback() {
        let input = [
            entry(title: "＋＋＋", releaseYear: 2021),
            entry(title: "＊＊＊", releaseYear: 2022)
        ]

        let result = CatalogStyleNormalizer.normalize(input, style: .anthology, collectionName: "France Culture")

        XCTAssertFalse(result.contains { ($0.slug ?? "").isEmpty })
        XCTAssertNotEqual(result[0].slug, result[1].slug)
    }
}
