import Foundation

enum StatisticsSectionKind: String, CaseIterable, Identifiable {
    case overview
    case topRated
    case moods

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: String(localized: "Statistics.Section.Overview", defaultValue: "Übersicht")
        case .topRated: String(localized: "Statistics.Section.TopRated", defaultValue: "Beste Bewertungen")
        case .moods: String(localized: "Statistics.Section.Moods", defaultValue: "Stimmungen")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .topRated: "star"
        case .moods: "tag"
        }
    }
}

enum StatisticsOverviewKind: String, CaseIterable, Identifiable {
    case episodes
    case listened
    case open
    case totalListens
    case averageRating
    case favorites
    case bookmarked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .episodes: String(localized: "Statistics.Overview.Episodes", defaultValue: "Folgen")
        case .listened: String(localized: "Statistics.Overview.Listened", defaultValue: "Gehört")
        case .open: String(localized: "Statistics.Overview.Open", defaultValue: "Offen")
        case .totalListens: String(localized: "Statistics.Overview.TotalListens", defaultValue: "Hördurchgänge")
        case .averageRating: String(localized: "Statistics.Overview.AverageRating", defaultValue: "Schnitt")
        case .favorites: String(localized: "Statistics.Overview.Favorites", defaultValue: "Favoriten")
        case .bookmarked: String(localized: "Statistics.Overview.Bookmarked", defaultValue: "Gemerkt")
        }
    }

    var systemImage: String {
        switch self {
        case .episodes: "list.number"
        case .listened: "checkmark.circle"
        case .open: "circle"
        case .totalListens: "ear"
        case .averageRating: "star"
        case .favorites: "heart.fill"
        case .bookmarked: "bookmark.fill"
        }
    }
}

enum StatisticsOverviewPreferences {
    static func orderedSections(from rawValue: String) -> [StatisticsSectionKind] {
        let saved = rawValue
            .split(separator: ",")
            .compactMap { StatisticsSectionKind(rawValue: String($0)) }

        var result: [StatisticsSectionKind] = []
        for section in saved where !result.contains(section) {
            result.append(section)
        }
        for section in StatisticsSectionKind.allCases where !result.contains(section) {
            result.append(section)
        }
        return result
    }

    static func hiddenSections(from rawValue: String) -> Set<StatisticsSectionKind> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { StatisticsSectionKind(rawValue: String($0)) }
        )
    }

    static func encodeSectionOrder(_ order: [StatisticsSectionKind]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    static func encodeHiddenSections(_ hiddenSections: Set<StatisticsSectionKind>) -> String {
        hiddenSections.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func orderedItems(
        from rawValue: String,
        availableKinds: Set<StatisticsOverviewKind>
    ) -> [StatisticsOverviewKind] {
        let saved = rawValue
            .split(separator: ",")
            .compactMap { StatisticsOverviewKind(rawValue: String($0)) }
            .filter { availableKinds.contains($0) }

        var result: [StatisticsOverviewKind] = []
        for section in saved where !result.contains(section) {
            result.append(section)
        }
        for section in StatisticsOverviewKind.allCases where availableKinds.contains(section) && !result.contains(section) {
            result.append(section)
        }
        return result
    }

    static func hiddenItems(
        from rawValue: String,
        availableKinds: Set<StatisticsOverviewKind>
    ) -> Set<StatisticsOverviewKind> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { StatisticsOverviewKind(rawValue: String($0)) }
                .filter { availableKinds.contains($0) }
        )
    }

    static func encodeOrder(_ order: [StatisticsOverviewKind]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    static func encodeHidden(_ hiddenItems: Set<StatisticsOverviewKind>) -> String {
        hiddenItems.map(\.rawValue).sorted().joined(separator: ",")
    }
}
