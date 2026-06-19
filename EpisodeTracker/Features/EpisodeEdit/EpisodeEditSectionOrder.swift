import Foundation

enum EpisodeEditSection: String, CaseIterable, Identifiable {
    case cover = "cover"
    case status = "status"
    case moods = "moods"
    case note = "note"
    case streaming = "streaming"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cover:     String(localized: "EpisodeEdit.Section.Cover", defaultValue: "Cover")
        case .status:    String(localized: "EpisodeEdit.Section.Status", defaultValue: "Status")
        case .moods:     String(localized: "EpisodeEdit.Section.Moods", defaultValue: "Stimmungen")
        case .note:      String(localized: "EpisodeEdit.Section.Note", defaultValue: "Persönliche Notiz")
        case .streaming: String(localized: "EpisodeEdit.Section.Streaming", defaultValue: "Streaming-Link")
        }
    }
}

enum EpisodeEditSectionOrder {
    static let storageKey = "episodeEditSectionOrder"

    static func sections(from rawValue: String) -> [EpisodeEditSection] {
        let saved = rawValue
            .split(separator: ",")
            .compactMap { EpisodeEditSection(rawValue: String($0)) }

        var result: [EpisodeEditSection] = []
        for item in saved where !result.contains(item) {
            result.append(item)
        }
        for item in EpisodeEditSection.allCases where !result.contains(item) {
            result.append(item)
        }
        return result
    }

    static func encode(_ order: [EpisodeEditSection]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }
}
