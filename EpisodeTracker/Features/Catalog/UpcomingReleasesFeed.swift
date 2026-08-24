import Foundation

struct UpcomingReleasesFeed {
    struct Row: Identifiable {
        let release: UpcomingRelease
        let seriesName: String

        var id: String { release.id }
    }

    let rows: [Row]
    let hasUnseen: Bool

    /// Genau die IDs, die gerade angezeigt werden - beim Merken wird nur diese
    /// Menge gespeichert, damit die "gesehen"-Liste sich selbst aufräumt.
    var visibleReleaseIDs: Set<String> {
        Set(rows.map(\.id))
    }

    static func make(
        releases: [UpcomingRelease],
        activeCatalogIDs: Set<String>,
        namesByCatalogID: [String: String],
        seenReleaseIDs: Set<String>,
        today: Date
    ) -> UpcomingReleasesFeed {
        let startOfToday = Calendar.current.startOfDay(for: today)

        let rows = releases
            .filter { activeCatalogIDs.contains($0.catalogID) && $0.releaseDate >= startOfToday }
            .compactMap { release -> Row? in
                guard let name = namesByCatalogID[release.catalogID] else { return nil }
                return Row(release: release, seriesName: name)
            }
            .sorted { ($0.release.releaseDate, $0.release.number) < ($1.release.releaseDate, $1.release.number) }

        return UpcomingReleasesFeed(
            rows: rows,
            hasUnseen: rows.contains { !seenReleaseIDs.contains($0.id) }
        )
    }
}
