import SwiftUI
import UIKit

/// Kleiner Saison-Akzent (Vault: „Saisonale Anpassungen“, Stufe 2). Nur die
/// Hörstand-Zeile und der leere Zustand lesen ihn, damit die Deko nicht in
/// andere Screens wandert.
struct SeasonalAccent: Equatable {
    let season: CatalogSeason

    /// `nil`, wenn keine Saison läuft oder „Saisonale Akzente“ aus ist.
    static func current(enabled: Bool, on date: Date = SeasonalContext.referenceDate) -> SeasonalAccent? {
        guard enabled, let season = SeasonalContext.activeSeason(on: date) else { return nil }
        return SeasonalAccent(season: season)
    }

    var symbol: String {
        switch season {
        case .christmas: "star.fill"
        }
    }

    /// Warmer Goldton statt Rot-Grün, damit der Akzent auch bei
    /// Farbfehlsichtigkeit nicht mit Fortschritt oder Fehler verwechselt wird.
    var tint: Color {
        switch season {
        case .christmas:
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.95, green: 0.74, blue: 0.32, alpha: 1)
                    : UIColor(red: 0.72, green: 0.48, blue: 0.10, alpha: 1)
            })
        }
    }

    /// Ein Satz für den leeren Zustand.
    var emptyStateHint: String {
        switch season {
        case .christmas:
            String(localized: "Seasonal.Christmas.EmptyHint", defaultValue: "Zeit für ein Weihnachtshörspiel?")
        }
    }
}
