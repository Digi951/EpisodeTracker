import Foundation

/// Kennzahlen für „Dein Hörjahr“ (Vault: „Saisonale Anpassungen“).
///
/// Es gibt keinen Hörverlauf, nur `lastListenedAt` pro Folge. Eine Folge
/// zählt deshalb einmal, im Jahr ihres letzten Durchgangs, und als gehört
/// Nachgetragenes zählt mit. Die Texte sagen darum „eingetragen“, und der
/// stärkste Monat lässt Nachtrage-Tage weg.
struct YearInReviewEngine {
    let year: Int
    let episodes: [Episode]
    private let calendar: Calendar

    /// Ab so vielen Einträgen an einem Tag gilt der Tag als Nachtragen und
    /// zählt für den stärksten Monat nicht mit. Zehn Folgen an einem Tag
    /// hört kaum jemand wirklich.
    static let bulkDayThreshold = 10

    init(episodes allEpisodes: [Episode], year: Int, calendar: Calendar = .current) {
        self.year = year
        self.calendar = calendar
        self.episodes = allEpisodes.filter { episode in
            guard !episode.isHidden, episode.listenCount > 0, let date = episode.lastListenedAt else { return false }
            return calendar.component(.year, from: date) == year
        }
    }

    /// Jahre mit mindestens einer eingetragenen Folge, aufsteigend.
    static func availableYears(episodes: [Episode], calendar: Calendar = .current) -> [Int] {
        let years = episodes.compactMap { episode -> Int? in
            guard !episode.isHidden, episode.listenCount > 0, let date = episode.lastListenedAt else { return nil }
            return calendar.component(.year, from: date)
        }
        return Set(years).sorted()
    }

    /// Im Januar das abgelaufene Jahr, sonst das laufende.
    static func defaultYear(on date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        return components.month == 1 ? year - 1 : year
    }

    var episodeCount: Int { episodes.count }

    private var snapshot: StatisticsSnapshot { StatisticsSnapshot(episodes: episodes) }

    /// Reihe mit den meisten Einträgen; bei Gleichstand alphabetisch.
    var favoriteSeries: (name: String, count: Int)? {
        var counts: [String: Int] = [:]
        for episode in episodes {
            counts[AppLocalization.displayName(forUniverseName: episode.universe?.name), default: 0] += 1
        }
        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .first
            .map { (name: $0.key, count: $0.value) }
    }

    /// Die drei am besten bewerteten Folgen des Jahres, beste zuerst.
    var podium: [Episode] { Array(snapshot.topRated.prefix(3)) }

    var topMoods: [(mood: Mood, count: Int)] {
        snapshot.moodDistribution.prefix(3).map { (mood: $0.0, count: $0.1) }
    }

    /// Monat (1–12) mit den meisten Einträgen, ohne Nachtrage-Tage. `nil`,
    /// wenn danach zu wenig übrig bleibt, um etwas zu sagen.
    var strongestMonth: (month: Int, count: Int)? {
        let days = Dictionary(grouping: episodes) { episode in
            calendar.startOfDay(for: episode.lastListenedAt ?? .distantPast)
        }
        var monthCounts: [Int: Int] = [:]
        for (day, dayEpisodes) in days where dayEpisodes.count < Self.bulkDayThreshold {
            monthCounts[calendar.component(.month, from: day), default: 0] += dayEpisodes.count
        }
        guard monthCounts.values.reduce(0, +) >= 3 else { return nil }
        return monthCounts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .first
            .map { (month: $0.key, count: $0.value) }
    }
}
