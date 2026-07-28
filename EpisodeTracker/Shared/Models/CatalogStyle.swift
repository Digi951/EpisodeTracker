import Foundation

/// Struktur eines Katalogs. `numbered` ist das deutsche Reihenmodell
/// (Die drei ???, TKKG): durchlaufende Nummern, Fortschritt gegen eine
/// Gesamtzahl, Sonderfolgen als Ausnahme. `anthology` beschreibt Kataloge
/// ohne Reihe — Einzelproduktionen, wie sie öffentlich-rechtliche Sender
/// in PL, NL und FR veröffentlichen. Dort ist jede Folge eigenständig,
/// und der Begriff „Sonderfolge" wäre sinnlos.
enum CatalogStyle: String, Codable, Sendable, CaseIterable {
    case numbered
    case anthology

    static func resolve(_ rawValue: String?) -> CatalogStyle {
        guard let rawValue else { return .numbered }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return CatalogStyle(rawValue: normalized) ?? .numbered
    }

    var usesEpisodeNumbers: Bool {
        self == .numbered
    }
}
