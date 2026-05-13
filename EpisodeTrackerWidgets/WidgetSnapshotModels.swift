import Foundation

struct WidgetLibrarySnapshot: Codable {
    var generatedAt: Date
    var libraryTitle: String
    var universes: [String]
    var episodes: [WidgetEpisodeSnapshot]
}

struct WidgetEpisodeSnapshot: Codable, Hashable {
    var id: UUID
    var episodeNumber: Int
    var title: String
    var releaseYear: Int
    var universeName: String?
    var isListened: Bool
    var rating: Int?
    var lastListenedAt: Date?
}
