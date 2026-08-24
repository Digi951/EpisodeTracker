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

        // upcoming_releases.json wird automatisch erzeugt und garantiert keine
        // eindeutigen Einträge - eine verschobene Folge kann doppelt auftauchen.
        // Doppelte IDs würden ForEach durcheinanderbringen, deshalb wird hier
        // dedupliziert und der frühere Termin behalten.
        var seenIDs: Set<String> = []

        let rows = releases
            .filter { activeCatalogIDs.contains($0.catalogID) && $0.releaseDate >= startOfToday }
            .sorted { ($0.releaseDate, $0.number) < ($1.releaseDate, $1.number) }
            .compactMap { release -> Row? in
                guard let name = namesByCatalogID[release.catalogID],
                      seenIDs.insert(release.id).inserted
                else {
                    return nil
                }
                return Row(release: release, seriesName: name)
            }

        return UpcomingReleasesFeed(
            rows: rows,
            hasUnseen: rows.contains { !seenReleaseIDs.contains($0.id) }
        )
    }

    /// Verdrahtung mit dem aktuellen App-Zustand an einer Stelle, damit iPhone-
    /// und iPad-Liste nicht auseinanderlaufen. `make` bleibt rein und testbar.
    @MainActor
    static func current(seenReleaseIDsRaw: String) -> UpcomingReleasesFeed {
        make(
            releases: EpisodeCatalog.shared.upcomingReleases,
            activeCatalogIDs: ActiveCatalogStore().activeIDs,
            namesByCatalogID: Dictionary(
                CatalogSourceRegistry.managedSources.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            ),
            seenReleaseIDs: Set(seenReleaseIDsRaw.split(separator: ",").map(String.init)),
            today: .now
        )
    }
}
