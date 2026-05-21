import Foundation

enum StreamingService: String, CaseIterable, Identifiable {
    case spotify
    case appleMusic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .appleMusic: "Apple Music"
        }
    }

    var iconName: String {
        switch self {
        case .spotify: "play.circle"
        case .appleMusic: "music.note"
        }
    }

    func catalogURL(from entry: CatalogEntry) -> URL? {
        switch self {
        case .spotify:
            return entry.spotifyURL.flatMap { URL(string: $0) }
        case .appleMusic:
            return entry.appleMusicURL.flatMap { URL(string: $0) }
        }
    }

    func directURL(from urlString: String?) -> URL? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

}
