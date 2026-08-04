import Foundation

struct CatalogUpdateBannerRecommendation: Equatable {
    let missingEpisodeCount: Int
    let universeCount: Int
    let firstUniverseName: String
    let firstEpisodeTitle: String
    let iconName: String
    let iconColorName: String
    private let titleText: String
    private let messageText: String
    private let compactMessageText: String

    init(
        missingEpisodeCount: Int,
        universeCount: Int,
        firstUniverseName: String,
        firstEpisodeTitle: String
    ) {
        self.missingEpisodeCount = missingEpisodeCount
        self.universeCount = universeCount
        self.firstUniverseName = firstUniverseName
        self.firstEpisodeTitle = firstEpisodeTitle
        self.iconName = "text.badge.plus"
        self.iconColorName = "green"
        titleText = missingEpisodeCount == 1
            ? String(localized: "CatalogUpdate.NewEpisodes.Title.One", defaultValue: "1 neue Katalogfolge")
            : AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Title.Many",
                defaultValue: "%lld neue Katalogfolgen",
                Int64(missingEpisodeCount)
            )
        if universeCount == 1 {
            messageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Message.OneUniverse",
                defaultValue: "%@: %@ wartet auf deine Bibliothek.",
                firstUniverseName,
                firstEpisodeTitle
            )
            compactMessageText = "\(firstUniverseName): \(firstEpisodeTitle)"
        } else {
            messageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Message.MultipleUniverses",
                defaultValue: "Aktive Kataloge haben neue Folgen, unter anderem %@ in %@.",
                firstEpisodeTitle,
                firstUniverseName
            )
            compactMessageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Compact.MultipleUniverses",
                defaultValue: "%lld Kataloge, u. a. %@",
                Int64(universeCount),
                firstUniverseName
            )
        }
    }

    private init(
        title: String,
        message: String,
        compactMessage: String,
        missingEpisodeCount: Int,
        universeCount: Int,
        firstUniverseName: String,
        firstEpisodeTitle: String,
        iconName: String = "text.badge.plus",
        iconColorName: String = "green"
    ) {
        self.missingEpisodeCount = missingEpisodeCount
        self.universeCount = universeCount
        self.firstUniverseName = firstUniverseName
        self.firstEpisodeTitle = firstEpisodeTitle
        self.iconName = iconName
        self.iconColorName = iconColorName
        titleText = title
        messageText = message
        compactMessageText = compactMessage
    }

    var title: String {
        titleText
    }

    var message: String {
        messageText
    }

    var compactMessage: String {
        compactMessageText
    }

    var fingerprint: String {
        "\(titleText)|\(universeCount)|\(missingEpisodeCount)|\(firstUniverseName)|\(firstEpisodeTitle)"
    }

    static func removedCatalogs(_ names: [String]) -> CatalogUpdateBannerRecommendation? {
        guard !names.isEmpty else { return nil }
        let title = names.count == 1
            ? String(localized: "CatalogUpdate.Removed.Title.One", defaultValue: "Katalog nicht mehr verfügbar")
            : AppLocalization.format(
                "CatalogUpdate.Removed.Title.Many",
                defaultValue: "%lld Kataloge nicht mehr verfügbar",
                Int64(names.count)
            )
        let message = names.count == 1
            ? AppLocalization.format(
                "CatalogUpdate.Removed.Message.One",
                defaultValue: "%@ wird nicht mehr unterstützt und wurde aus deinen aktiven Katalogen entfernt.",
                names[0]
            )
            : AppLocalization.format(
                "CatalogUpdate.Removed.Message.Many",
                defaultValue: "%@ werden nicht mehr unterstützt und wurden aus deinen aktiven Katalogen entfernt.",
                catalogList(names)
            )
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: names.count == 1
                ? names[0]
                : AppLocalization.format(
                    "CatalogUpdate.Removed.Compact.Many",
                    defaultValue: "%lld Kataloge entfernt",
                    Int64(names.count)
                ),
            missingEpisodeCount: 0,
            universeCount: names.count,
            firstUniverseName: names[0],
            firstEpisodeTitle: names[0],
            iconName: "text.badge.minus",
            iconColorName: "orange"
        )
    }

    static func newCatalogs(_ availability: NewCatalogAvailability) -> CatalogUpdateBannerRecommendation? {
        guard let firstName = availability.firstName else { return nil }
        let title = availability.count == 1
            ? String(localized: "CatalogUpdate.NewCatalogs.Title.One", defaultValue: "1 neuer Katalog verfügbar")
            : AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Title.Many",
                defaultValue: "%lld neue Kataloge verfügbar",
                Int64(availability.count)
            )
        let message = availability.count == 1
            ? AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Message.One",
                defaultValue: "%@ kann in den Katalogen aktiviert werden.",
                firstName
            )
            : AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Message.Many",
                defaultValue: "%@ und weitere Kataloge können aktiviert werden.",
                firstName
            )
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: availability.count == 1
                ? firstName
                : AppLocalization.format(
                    "CatalogUpdate.NewCatalogs.Compact.Many",
                    defaultValue: "%lld neue Kataloge",
                    Int64(availability.count)
                ),
            missingEpisodeCount: 0,
            universeCount: availability.count,
            firstUniverseName: firstName,
            firstEpisodeTitle: firstName
        )
    }

    static func newActiveCatalogs(_ availability: NewCatalogAvailability) -> CatalogUpdateBannerRecommendation? {
        guard let firstName = availability.firstName else { return nil }
        let title = availability.count == 1
            ? String(localized: "CatalogUpdate.NewActiveCatalogs.Title.One", defaultValue: "Neuer Katalog hinzugefügt")
            : AppLocalization.format(
                "CatalogUpdate.NewActiveCatalogs.Title.Many",
                defaultValue: "%lld neue Kataloge hinzugefügt",
                Int64(availability.count)
            )
        let message = availability.count == 1
            ? AppLocalization.format(
                "CatalogUpdate.NewActiveCatalogs.Message.One",
                defaultValue: "%@ wurde deiner Bibliothek hinzugefügt.",
                firstName
            )
            : AppLocalization.format(
                "CatalogUpdate.NewActiveCatalogs.Message.Many",
                defaultValue: "%@ und weitere Kataloge wurden deiner Bibliothek hinzugefügt.",
                firstName
            )
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: availability.count == 1
                ? firstName
                : AppLocalization.format(
                    "CatalogUpdate.NewCatalogs.Compact.Many",
                    defaultValue: "%lld neue Kataloge",
                    Int64(availability.count)
                ),
            missingEpisodeCount: 0,
            universeCount: availability.count,
            firstUniverseName: firstName,
            firstEpisodeTitle: firstName
        )
    }

    static func episodeDelta(_ delta: CatalogEpisodeDelta) -> CatalogUpdateBannerRecommendation? {
        guard delta.addedCount > 0,
              let firstTitle = delta.firstAddedTitle
        else {
            return nil
        }

        let title = delta.addedCount == 1
            ? AppLocalization.format(
                "CatalogUpdate.Delta.Title.One",
                defaultValue: "1 neue Katalogfolge in %@",
                delta.name
            )
            : AppLocalization.format(
                "CatalogUpdate.Delta.Title.Many",
                defaultValue: "%lld neue Katalogfolgen in %@",
                Int64(delta.addedCount),
                delta.name
            )
        let versionText: String
        if let previousVersion = delta.previousVersion, let currentVersion = delta.currentVersion {
            versionText = AppLocalization.format(
                "CatalogUpdate.Delta.Version",
                defaultValue: "Version %@ -> %@",
                String(previousVersion),
                String(currentVersion)
            )
        } else {
            versionText = AppLocalization.format(
                "CatalogUpdate.Delta.EpisodeCountChange",
                defaultValue: "%lld -> %lld Folgen",
                Int64(delta.previousEntryCount),
                Int64(delta.currentEntryCount)
            )
        }
        let message = delta.addedCount == 1
            ? AppLocalization.format(
                "CatalogUpdate.Delta.Message.One",
                defaultValue: "%@ wurde ergänzt.",
                firstTitle
            )
            : AppLocalization.format(
                "CatalogUpdate.Delta.Message.Many",
                defaultValue: "%@ und weitere neue Folgen wurden ergänzt.",
                firstTitle
            )

        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: AppLocalization.format(
                "CatalogUpdate.Delta.Compact",
                defaultValue: "%@ - %lld Folgen",
                versionText,
                Int64(delta.currentEntryCount)
            ),
            missingEpisodeCount: delta.addedCount,
            universeCount: 1,
            firstUniverseName: delta.name,
            firstEpisodeTitle: firstTitle
        )
    }

    /// Folds every pending catalog delta into a single banner so that no
    /// catalog's update is shadowed by a larger one. A single delta keeps the
    /// detailed per-catalog wording.
    static func aggregatedEpisodeDeltas(_ deltas: [CatalogEpisodeDelta]) -> CatalogUpdateBannerRecommendation? {
        let relevant = deltas
            .filter { $0.addedCount > 0 }
            .sorted {
                if $0.addedCount != $1.addedCount {
                    return $0.addedCount > $1.addedCount
                }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }

        guard let top = relevant.first else { return nil }
        guard relevant.count > 1, let firstTitle = top.firstAddedTitle else {
            return episodeDelta(top)
        }

        let totalAdded = relevant.reduce(0) { $0 + $1.addedCount }
        return CatalogUpdateBannerRecommendation(
            title: AppLocalization.format(
                "CatalogUpdate.Aggregated.Title",
                defaultValue: "%lld neue Katalogfolgen in %lld Katalogen",
                Int64(totalAdded),
                Int64(relevant.count)
            ),
            message: AppLocalization.format(
                "CatalogUpdate.Aggregated.Message",
                defaultValue: "Neue Folgen in %@.",
                catalogList(relevant.map(\.name))
            ),
            compactMessage: AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Compact.MultipleUniverses",
                defaultValue: "%lld Kataloge, u. a. %@",
                Int64(relevant.count),
                top.name
            ),
            missingEpisodeCount: totalAdded,
            universeCount: relevant.count,
            firstUniverseName: top.name,
            firstEpisodeTitle: firstTitle
        )
    }

    private static func catalogList(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return AppLocalization.format(
                "CatalogUpdate.List.Two",
                defaultValue: "%@ und %@",
                names[0],
                names[1]
            )
        case 3:
            return AppLocalization.format(
                "CatalogUpdate.List.Three",
                defaultValue: "%@, %@ und %@",
                names[0],
                names[1],
                names[2]
            )
        default:
            return AppLocalization.format(
                "CatalogUpdate.List.Many",
                defaultValue: "%@, %@ und %lld weiteren Katalogen",
                names[0],
                names[1],
                Int64(names.count - 2)
            )
        }
    }

    #if DEBUG
    static let previewNewCatalogs = CatalogUpdateBannerRecommendation.newCatalogs(
        NewCatalogAvailability(sources: [
            ManagedCatalogSource(id: "bibi", name: "Bibi und Tina", url: URL(string: "https://example.com")!),
            ManagedCatalogSource(id: "tkkg", name: "TKKG", url: URL(string: "https://example.com")!)
        ])
    )

    static let previewNewEpisodes = CatalogUpdateBannerRecommendation(
        missingEpisodeCount: 5,
        universeCount: 1,
        firstUniverseName: "Die drei ???",
        firstEpisodeTitle: "und der Super-Papagei"
    )
    #endif
}
