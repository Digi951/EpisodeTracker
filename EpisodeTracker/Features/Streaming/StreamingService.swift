import Foundation

enum StreamingService: String, CaseIterable, Identifiable {
    case spotify
    case apple
    case deezer
    case audible

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "spotify": self = .spotify
        case "apple", "appleMusic": self = .apple
        case "deezer": self = .deezer
        case "audible": self = .audible
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .apple: "Apple"
        case .deezer: "Deezer"
        case .audible: "Audible"
        }
    }

    func displayName(for url: String?) -> String {
        guard self == .apple, let url else { return displayName }
        if url.contains("music.apple.com") { return "Apple Music" }
        if url.contains("books.apple.com") { return "Apple Books" }
        return "Apple"
    }

    var iconName: String {
        switch self {
        case .spotify: "play.circle"
        case .apple: "music.note"
        case .deezer: "music.note.list"
        case .audible: "headphones"
        }
    }

    func catalogURL(from entry: CatalogEntry) -> URL? {
        switch self {
        case .spotify:
            return entry.spotifyURL.flatMap { URL(string: $0) }
        case .apple:
            return entry.appleMusicURL.flatMap { URL(string: $0) }
        case .deezer:
            return entry.deezerURL.flatMap { URL(string: $0) }
        case .audible:
            return entry.audibleURL.flatMap { URL(string: $0) }
        }
    }

    func directURL(from urlString: String?) -> URL? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
