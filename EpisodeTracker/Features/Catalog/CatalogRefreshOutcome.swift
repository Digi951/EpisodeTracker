import Foundation

/// Aggregiertes Ergebnis eines Refresh-Laufs über Manifest, aktive Kataloge und
/// den Bald-verfügbar-Feed. Ersetzt das frühere einzelne `lastRefreshError: String?`,
/// bei dem in der parallelen `TaskGroup` der letzte Schreiber gewann und Teil-Erfolg
/// nicht sichtbar war.
///
/// `lastRefreshError` bleibt als abgeleiteter Anzeige-String erhalten (für den
/// bestehenden Katalog-Banner), wird aber aus diesem Objekt berechnet.
struct CatalogRefreshOutcome: Equatable {
    enum Status: Equatable {
        case updated
        case notModified
        case failed(CatalogFetchError)

        var isSuccess: Bool {
            switch self {
            case .updated, .notModified: return true
            case .failed: return false
            }
        }
    }

    struct SourceResult: Equatable {
        let id: String
        let name: String
        let status: Status
        /// Zeitpunkt dieses Abrufversuchs — unabhängig davon, ob er geglückt ist.
        let lastAttemptAt: Date
        /// Letzter *erfolgreicher* Abruf laut Cache-Metadaten. Bleibt bei einem
        /// Fehlschlag erhalten, wird also nicht durch den Versuch überschrieben.
        let lastSuccessAt: Date?

        var didFail: Bool { !status.isSuccess }
    }

    /// Verzeichnis-Abruf. `nil`, wenn der Lauf ihn nicht angefasst hat (gedrosselt).
    var manifest: SourceResult?
    /// Bald-verfügbar-Feed. Fehlschläge hier zählen bewusst **nicht** in den
    /// abgeleiteten Katalog-Fehlertext (Zusatzfeature), stehen aber für eine
    /// künftige Neuigkeiten-Statusanzeige zur Verfügung.
    var upcoming: SourceResult?
    /// Je aktiver Katalog ein Ergebnis; gedrosselte Kataloge fehlen.
    var sources: [SourceResult]

    init(manifest: SourceResult? = nil, upcoming: SourceResult? = nil, sources: [SourceResult] = []) {
        self.manifest = manifest
        self.upcoming = upcoming
        self.sources = sources
    }

    /// Alle Ergebnisse inkl. Bald-verfügbar — für vollständige Diagnose.
    var allResults: [SourceResult] {
        ([manifest, upcoming].compactMap { $0 }) + sources
    }

    var hadAnySuccess: Bool { allResults.contains { !$0.didFail } }
    var hadAnyFailure: Bool { allResults.contains(where: \.didFail) }

    /// Namen aller gescheiterten Quellen inkl. Bald-verfügbar.
    var failedNames: [String] { allResults.filter(\.didFail).map(\.name) }

    /// Gescheiterte *Kataloge* (aktive Quellen, ohne Verzeichnis und
    /// Bald-verfügbar) — Basis für den abgeleiteten Anzeige-String.
    var failedCatalogNames: [String] { sources.filter(\.didFail).map(\.name) }

    var manifestFailed: Bool { manifest?.didFail == true }

    /// Wie viele Kataloge in diesem Lauf tatsächlich abgerufen wurden (ohne
    /// gedrosselte). Basis für „x von y nicht aktualisierbar".
    var attemptedCatalogCount: Int { sources.count }
}

extension CatalogFetchError {
    /// Kompakte, stabile Kennung für `RemoteCatalogMetadata.lastFailureKind`
    /// (Persistenz + Debug), z. B. `"http:404"`, `"transport:-1001"`.
    var kindLabel: String {
        switch self {
        case .http(let status): return "http:\(status)"
        case .transport(let code): return "transport:\(code)"
        case .notHTTP: return "notHTTP"
        case .decoding: return "decoding"
        }
    }
}
