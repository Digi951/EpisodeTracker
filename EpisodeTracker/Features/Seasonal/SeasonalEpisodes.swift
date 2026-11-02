import Foundation

/// Welche Saison gerade läuft (Vault: „Saisonale Anpassungen“). Die Saison
/// ändert, was die App vorschlägt, nicht wie sie aussieht. Bisher nur Advent.
enum SeasonalContext {
    /// Schalter „Saisonale Akzente“ in den Einstellungen, Standard an.
    static let accentsEnabledKey = "seasonalAccentsEnabled"

#if DEBUG
    /// Launch-Argument `-seasonalDebugDate 2026-12-10`, um die Saison
    /// außerhalb des Dezembers im Simulator zu prüfen.
    static let debugDateKey = "seasonalDebugDate"
#endif

    nonisolated static func activeSeason(on date: Date, calendar: Calendar = .current) -> CatalogSeason? {
        let components = calendar.dateComponents([.month, .day], from: date)
        // Advent plus die beiden Feiertage: Weihnachtsfolgen hört man auch noch
        // am 25. und 26.
        if components.month == 12, let day = components.day, day <= 26 {
            return .christmas
        }
        return nil
    }

    static var referenceDate: Date {
#if DEBUG
        if let raw = UserDefaults.standard.string(forKey: debugDateKey),
           let date = CalendarDayFormatter.date(from: raw) {
            return date
        }
#endif
        return .now
    }
}

/// Inhalt der Saison-Liste: eigene Folgen mit Saison-Markierung im Katalog
/// und markierte Katalogfolgen, die noch fehlen.
struct SeasonalEpisodes {
    let season: CatalogSeason
    /// Ungehörte zuerst, ausgeblendete nie.
    let libraryEpisodes: [Episode]
    /// Nur aus aktiven Katalogen; Folgen in der Bibliothek fehlen hier.
    let catalogEntries: [CatalogEpisodeSearch.Result]

    var isEmpty: Bool { libraryEpisodes.isEmpty && catalogEntries.isEmpty }
    var unlistenedCount: Int { libraryEpisodes.filter { !$0.isListened }.count }

    nonisolated static func make(
        season: CatalogSeason,
        entries: [CatalogEntry],
        activeCollectionNames: Set<String>,
        libraryEpisodes: [Episode]
    ) -> SeasonalEpisodes {
        let tagged = entries.filter { $0.season == season && $0.collectionName != nil }

        var taggedNumbers: [String: Set<Int>] = [:]
        var taggedSlugs: [String: Set<String>] = [:]
        for entry in tagged {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(entry.collectionName ?? "")
            switch entry.kind {
            case .regular:
                if let number = entry.number { taggedNumbers[key, default: []].insert(number) }
            case .special:
                if let slug = entry.slug?.lowercased() { taggedSlugs[key, default: []].insert(slug) }
            }
        }

        // Eigene Folgen über den Katalog ihrer Reihe zuordnen, auch wenn der
        // Katalog gerade nicht aktiv ist.
        let owned = libraryEpisodes.filter { episode in
            guard !episode.isHidden, let universeName = episode.universe?.name else { return false }
            let key = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
            if episode.isSpecial {
                guard let slug = episode.catalogSlug?.lowercased() else { return false }
                return taggedSlugs[key]?.contains(slug) == true
            }
            return taggedNumbers[key]?.contains(episode.episodeNumber) == true
        }
        .sorted { lhs, rhs in
            if lhs.isListened != rhs.isListened { return !lhs.isListened }
            let lhsName = lhs.universe?.name ?? ""
            let rhsName = rhs.universe?.name ?? ""
            if lhsName != rhsName {
                return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
            }
            if lhs.episodeNumber != rhs.episodeNumber { return lhs.episodeNumber < rhs.episodeNumber }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }

        let existingNumbers = CatalogLibraryMatcher.existingNumbersByCollection(libraryEpisodes: libraryEpisodes)
        let existingSlugs = CatalogLibraryMatcher.existingSpecialSlugsByCollection(libraryEpisodes: libraryEpisodes)
        var seen = Set<String>()
        let missing = tagged.compactMap { entry -> CatalogEpisodeSearch.Result? in
            guard let collectionName = entry.collectionName else { return nil }
            let key = CatalogLibraryMatcher.normalizedCollectionKey(collectionName)
            guard activeCollectionNames.contains(key) else { return nil }

            let identity: String
            switch entry.kind {
            case .regular:
                guard let number = entry.number,
                      existingNumbers[key]?.contains(number) != true
                else { return nil }
                identity = String(number)
            case .special:
                let slug = entry.slug?.lowercased()
                if let slug, existingSlugs[key]?.contains(slug) == true { return nil }
                identity = "special:\(slug ?? entry.title)"
            }
            guard seen.insert("\(key)#\(identity)").inserted else { return nil }
            return CatalogEpisodeSearch.Result(universeName: collectionName, entry: entry)
        }
        .sorted { lhs, rhs in
            if lhs.universeName != rhs.universeName {
                return lhs.universeName.localizedStandardCompare(rhs.universeName) == .orderedAscending
            }
            // Neueste zuerst: Adventskalender und aktuelle Specials sind meist
            // das, was man gerade sucht.
            if lhs.entry.releaseYear != rhs.entry.releaseYear {
                return lhs.entry.releaseYear > rhs.entry.releaseYear
            }
            return (lhs.entry.number ?? Int.max) < (rhs.entry.number ?? Int.max)
        }

        return SeasonalEpisodes(season: season, libraryEpisodes: owned, catalogEntries: missing)
    }
}

extension CatalogSeason {
    var listTitle: String {
        switch self {
        case .christmas: String(localized: "Seasonal.Christmas.Title", defaultValue: "Weihnachtsfolgen")
        }
    }

    var systemImage: String {
        switch self {
        case .christmas: "gift.fill"
        }
    }
}
