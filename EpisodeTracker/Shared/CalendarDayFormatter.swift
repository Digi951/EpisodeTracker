import Foundation

/// Einheitlicher Parser/Formatter für reine Kalendertage (`"2026-09-18"`, ohne
/// Uhrzeit), wie sie im Katalog-Datenvertrag an mehreren Stellen vorkommen
/// (`UpcomingRelease.releaseDate`, `CatalogEntry.releaseDate` / `sourceCheckedAt`
/// / `changedAt`).
///
/// Verankerung an **lokale Mitternacht**, nicht an UTC: sonst zeigt eine Zeitzone
/// westlich von UTC den Vortag an und blendet die Folge am Erscheinungstag aus.
/// Cache-JSON und Remote-JSON nutzen exakt dieses Format, damit beide Wege
/// denselben `Date`-Wert ergeben.
///
/// Die Konfiguration ist 1:1 aus dem früheren privaten `UpcomingRelease
/// .dayFormatter()` übernommen; `DateFormatter` ist seit iOS 7 für reines
/// Parsen/Formatieren thread-sicher, deshalb eine geteilte Instanz statt einer
/// Allokation pro Eintrag.
enum CalendarDayFormatter {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()

    /// `nil`, wenn `raw` nicht dem Muster `yyyy-MM-dd` entspricht.
    static func date(from raw: String) -> Date? {
        formatter.date(from: raw)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
