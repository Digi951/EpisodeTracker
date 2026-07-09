import Foundation
import SwiftData
import os.log

#if DEBUG
enum DemoDataProvider {
    static let userDefaultsKey = "isDemoModeActive"

    private static let logger = Logger(
        subsystem: "com.Digi.EpisodeTracker",
        category: "DemoDataProvider"
    )

    static func makeContainerSet() -> AppModelContainerSet {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Episode.self, Mood.self, Universe.self,
                configurations: config
            )
            seed(into: ModelContext(container))
            return AppModelContainerSet(
                primary: container,
                localPersistent: nil,
                cloudPersistent: nil,
                runtimeMode: .demo
            )
        } catch {
            fatalError("Demo container creation failed: \(error)")
        }
    }

    private static func seed(into context: ModelContext) {
        // Moods
        let klassiker = Mood(name: "Klassiker", iconName: "🎖")
        let spannend = Mood(name: "Spannend", iconName: "⚡")
        let gruselig = Mood(name: "Gruselig", iconName: "😱")
        let entspannt = Mood(name: "Entspannt", iconName: "☕")
        [klassiker, spannend, gruselig, entspannt].forEach { context.insert($0) }

        // Universe 1: Die drei Detektive (wink: Die drei ???)
        let detektive = Universe(name: "Die drei Detektive")
        context.insert(detektive)

        let d1 = Episode(episodeNumber: 1,
            title: "... und das Geheimnis des alten Leuchtturms",
            releaseYear: 1979, isListened: true, rating: 5, listenCount: 3,
            universe: detektive, moods: [klassiker, spannend])
        let d2 = Episode(episodeNumber: 2,
            title: "... und der silberne Phantom-Motorradfahrer",
            releaseYear: 1980, isListened: true, rating: 4, listenCount: 2,
            universe: detektive, moods: [spannend])
        let d3 = Episode(episodeNumber: 3,
            title: "... und das flüsternde Schloss",
            releaseYear: 1980, isListened: true, rating: 5, listenCount: 4,
            universe: detektive, moods: [gruselig, klassiker])
        let d4 = Episode(episodeNumber: 4,
            title: "... und die verschwundene Uhr",
            releaseYear: 1981, isListened: true, rating: 3, listenCount: 1,
            universe: detektive, moods: [spannend])
        let d5 = Episode(episodeNumber: 5,
            title: "... und der brennende Berg",
            releaseYear: 1982, isListened: true, rating: 4, listenCount: 2,
            universe: detektive, moods: [spannend, gruselig])
        let d6 = Episode(episodeNumber: 6,
            title: "... und die tanzenden Schatten",
            releaseYear: 1982, isListened: false,
            universe: detektive)
        let d7 = Episode(episodeNumber: 7,
            title: "... und das Gespensterschiff",
            releaseYear: 1983, isListened: false,
            universe: detektive, moods: [gruselig])
        [d1, d2, d3, d4, d5, d6, d7].forEach { context.insert($0) }

        // Universe 2: TKKF (wink: TKKG)
        let tkkf = Universe(name: "TKKF – Team für knifflige Kriminalfälle")
        context.insert(tkkf)

        let t1 = Episode(episodeNumber: 1,
            title: "TKKF und der Bankräuber im Nebel",
            releaseYear: 1981, isListened: true, rating: 4, listenCount: 1,
            universe: tkkf, moods: [spannend])
        let t2 = Episode(episodeNumber: 2,
            title: "TKKF und die gestohlene Formel",
            releaseYear: 1982, isListened: true, rating: 3, listenCount: 1,
            universe: tkkf, moods: [spannend])
        let t3 = Episode(episodeNumber: 3,
            title: "TKKF und der rote Drache",
            releaseYear: 1983, isListened: true, rating: 4, listenCount: 2,
            universe: tkkf, moods: [spannend, gruselig])
        let t4 = Episode(episodeNumber: 4,
            title: "TKKF und der Diamantenraub",
            releaseYear: 1984, isListened: false,
            universe: tkkf)
        let t5 = Episode(episodeNumber: 5,
            title: "TKKF und der Eisenbahn-Coup",
            releaseYear: 1984, isListened: false,
            universe: tkkf)
        [t1, t2, t3, t4, t5].forEach { context.insert($0) }

        // Universe 3: Fünf Freigeister (wink: Fünf Freunde / Famous Five)
        let freigeister = Universe(name: "Fünf Freigeister")
        context.insert(freigeister)

        let f1 = Episode(episodeNumber: 1,
            title: "Fünf Freigeister auf Abenteuer",
            releaseYear: 1975, isListened: true, rating: 4, listenCount: 1,
            universe: freigeister, moods: [klassiker, entspannt])
        let f2 = Episode(episodeNumber: 2,
            title: "Fünf Freigeister und das verschwundene Insel-Erbe",
            releaseYear: 1976, isListened: true, rating: 3, listenCount: 1,
            universe: freigeister, moods: [entspannt])
        let f3 = Episode(episodeNumber: 3,
            title: "Fünf Freigeister und die verbotene Mine",
            releaseYear: 1977, isListened: false,
            universe: freigeister)
        [f1, f2, f3].forEach { context.insert($0) }

        do {
            try context.save()
        } catch {
            logger.error("Demo seeding failed to save: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
