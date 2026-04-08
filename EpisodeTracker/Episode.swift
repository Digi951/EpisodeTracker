import Foundation
import SwiftData

@Model
final class Episode {
    var episodeNumber: Int
    var title: String
    var releaseYear: Int
    var personalNote: String?
    var isListened: Bool
    var rating: Int?
    var listenCount: Int
    var lastListenedAt: Date?
    var universe: Universe?
    var moods: [Mood]

    init(
        episodeNumber: Int,
        title: String,
        releaseYear: Int,
        personalNote: String? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int = 0,
        lastListenedAt: Date? = nil,
        universe: Universe? = nil,
        moods: [Mood] = []
    ) {
        self.episodeNumber = episodeNumber
        self.title = title
        self.releaseYear = releaseYear
        self.personalNote = personalNote
        self.isListened = isListened
        self.rating = rating
        self.listenCount = listenCount
        self.lastListenedAt = lastListenedAt
        self.universe = universe
        self.moods = moods
    }
}
