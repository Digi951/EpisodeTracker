import Foundation

struct SavedFilter: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var statusFilterRaw: String
    // Names are intentionally stored as values instead of SwiftData IDs so saved filters stay decoupled from models.
    // If a universe or mood is renamed/deleted, that filter dimension may no longer match until the user updates it.
    var universeName: String?
    var moodName: String?
    var sortOrderRaw: String

    init(
        id: UUID = UUID(),
        name: String,
        statusFilter: EpisodeStatusFilter = .all,
        universeName: String? = nil,
        moodName: String? = nil,
        sortOrder: EpisodeSortOrder = .number
    ) {
        self.id = id
        self.name = name
        self.statusFilterRaw = statusFilter.rawValue
        self.universeName = universeName
        self.moodName = moodName
        self.sortOrderRaw = sortOrder.rawValue
    }

    var resolvedStatusFilter: EpisodeStatusFilter {
        EpisodeStatusFilter(rawValue: statusFilterRaw) ?? .all
    }

    var resolvedSortOrder: EpisodeSortOrder {
        EpisodeSortOrder(rawValue: sortOrderRaw) ?? .number
    }

    var summaryText: String {
        var parts: [String] = []
        if resolvedStatusFilter != .all {
            parts.append(resolvedStatusFilter.displayName)
        }
        if let universeName {
            parts.append(universeName)
        }
        if let moodName {
            parts.append(moodName)
        }
        if resolvedSortOrder != .number {
            parts.append(resolvedSortOrder.displayName)
        }
        return parts.isEmpty
            ? String(localized: "SavedFilter.Summary.AllEpisodes", defaultValue: "Alle Folgen")
            : parts.joined(separator: " · ")
    }
}

@Observable
final class SavedFilterStore {
    private static let storageKey = "savedFilters"
    private let defaults: UserDefaults

    private(set) var filters: [SavedFilter] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ filter: SavedFilter) {
        filters.append(filter)
        persist()
    }

    func update(_ filter: SavedFilter) {
        guard let index = filters.firstIndex(where: { $0.id == filter.id }) else { return }
        filters[index] = filter
        persist()
    }

    func delete(_ filter: SavedFilter) {
        filters.removeAll { $0.id == filter.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SavedFilter].self, from: data) else { return }
        filters = decoded
    }
}
