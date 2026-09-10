import XCTest
@testable import EpisodeTracker

/// Sichert die aus `UpcomingRelease.dayFormatter()` extrahierte, geteilte
/// Kalendertag-Logik ab. Verhalten muss identisch bleiben — dieselben Rohwerte
/// ergeben denselben `Date`, damit bestehende Cache-Dateien und Remote-Feeds
/// nach der Extraktion Bit für Bit gleich gelesen werden.
final class CalendarDayFormatterTests: XCTestCase {

    func testParsesPlainCalendarDayToLocalMidnight() {
        let date = CalendarDayFormatter.date(from: "2026-09-18")
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(date, Calendar.current.startOfDay(for: date!))
    }

    func testRejectsNonISOFormats() {
        XCTAssertNil(CalendarDayFormatter.date(from: "18.09.2026"))
        XCTAssertNil(CalendarDayFormatter.date(from: "2026-09-18T12:00:00Z"))
        XCTAssertNil(CalendarDayFormatter.date(from: ""))
        XCTAssertNil(CalendarDayFormatter.date(from: "nonsense"))
    }

    func testRoundTripsWithoutDayDrift() {
        for raw in ["2026-01-01", "2026-09-11", "2026-12-31", "2024-02-29"] {
            let date = CalendarDayFormatter.date(from: raw)
            XCTAssertNotNil(date, "\(raw) sollte parsen")
            XCTAssertEqual(CalendarDayFormatter.string(from: date!), raw)
        }
    }

    func testMatchesLegacyPrivateFormatterConfiguration() {
        // Nachbau des früheren privaten UpcomingRelease.dayFormatter().
        let legacy = DateFormatter()
        legacy.dateFormat = "yyyy-MM-dd"
        legacy.calendar = Calendar(identifier: .gregorian)
        legacy.locale = Locale(identifier: "en_US_POSIX")
        legacy.timeZone = .current

        for raw in ["1999-12-31", "2026-09-18", "2020-02-29", "2026-03-29"] {
            XCTAssertEqual(CalendarDayFormatter.date(from: raw), legacy.date(from: raw), "Parse-Abweichung bei \(raw)")
        }
    }
}
