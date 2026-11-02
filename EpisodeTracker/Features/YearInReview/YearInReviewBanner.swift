import SwiftUI

/// Einmaliger Hinweis auf „Dein Hörjahr“ über der Folgenliste, zwischen den
/// Jahren (Vault: „Saisonale Anpassungen“). Hängt am Schalter „Saisonale
/// Akzente“. Schließen oder Öffnen blendet ihn für dieses Jahr aus.
enum YearInReviewBanner {
    static let dismissedYearKey = "dismissedYearInReviewBannerYear"

    /// Das Jahr, auf das der Hinweis zeigt: vom 27. Dezember bis 6. Januar
    /// das ablaufende Jahr, sonst `nil`.
    nonisolated static func year(on date: Date, calendar: Calendar = .current) -> Int? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        if month == 12, day >= 27 { return year }
        if month == 1, day <= 6 { return year - 1 }
        return nil
    }

    /// Jahr für das Banner, oder `nil`, wenn es nicht erscheinen soll.
    static func pendingYear(
        episodes: [Episode],
        dismissedYear: Int,
        accentsEnabled: Bool,
        on date: Date = SeasonalContext.referenceDate,
        calendar: Calendar = .current
    ) -> Int? {
        guard accentsEnabled, let year = year(on: date, calendar: calendar), year != dismissedYear else { return nil }
        let engine = YearInReviewEngine(episodes: episodes, year: year, calendar: calendar)
        return engine.episodeCount > 0 ? year : nil
    }
}

struct YearInReviewBannerRow: View {
    let year: Int
    let style: FeatureAnnouncementBannerStyle
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HomeBannerView(
            style: style,
            systemImage: "sparkles",
            title: YearInReviewPoster.title(year: year),
            message: String(
                localized: "YearInReview.Banner.Message",
                defaultValue: "Dein Rückblick aufs Jahr ist da. Ansehen und teilen."
            ),
            onTap: onOpen,
            onDismiss: onDismiss
        )
        .listRowInsets(style == .sidebar
            ? EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)
            : EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
