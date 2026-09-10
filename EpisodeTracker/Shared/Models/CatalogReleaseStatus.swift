import Foundation

/// Veröffentlichungsstatus eines Katalogeintrags bzw. einer Terminzeile.
///
/// Regeln aus dem Datenvertrag (`docs/catalog-data-contract.md`):
/// - Fehlt das Feld, gilt `unknown`. Solche Einträge sind vollwertig nutzbar
///   (Bibliothek, Statistik, Autocomplete) — sie sind nur nicht „erschienen".
/// - `unknown` wird **nie** automatisch zu `released` umgedeutet.
/// - Kein `delayed`/`cancelled` in V1.18: eine Terminverschiebung ist eine
///   Änderung an `releaseDate` (+ `changedAt`), kein eigener Status.
enum CatalogReleaseStatus: String, Codable, Sendable, CaseIterable {
    case announced
    case released
    case unknown

    /// Tolerant gegen unbekannte Server-Rohwerte: alles Nicht-Erkannte (und
    /// `nil`) wird `unknown`, damit ein neuer Katalogwert nie den ganzen
    /// Payload scheitern lässt. Analog zu `CatalogStyle.resolve`.
    static func resolve(_ rawValue: String?) -> CatalogReleaseStatus {
        guard let rawValue else { return .unknown }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return CatalogReleaseStatus(rawValue: normalized) ?? .unknown
    }
}
