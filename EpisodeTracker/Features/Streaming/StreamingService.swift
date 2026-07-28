import Foundation

enum StreamingService: String, CaseIterable, Identifiable {
    case spotify
    case apple
    case deezer
    case audible
    case audioteka
    case storytel

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "spotify": self = .spotify
        case "apple", "appleMusic": self = .apple
        case "deezer": self = .deezer
        case "audible": self = .audible
        case "audioteka": self = .audioteka
        case "storytel": self = .storytel
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .apple: "Apple"
        case .deezer: "Deezer"
        case .audible: "Audible"
        case .audioteka: "Audioteka"
        case .storytel: "Storytel"
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
        case .audioteka: "waveform.circle"
        case .storytel: "book.circle"
        }
    }

    /// Ein Dictionary-Lookup statt eines `switch` über alle Dienste: ein neuer
    /// Dienst braucht hier keine Änderung mehr, nur einen neuen Enum-Case.
    func catalogURL(from entry: CatalogEntry) -> URL? {
        directURL(from: entry.links[rawValue])
    }

    func directURL(from urlString: String?) -> URL? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
