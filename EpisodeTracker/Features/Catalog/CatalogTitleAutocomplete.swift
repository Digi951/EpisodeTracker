import Foundation

enum CatalogTitleAutocomplete {
    nonisolated static func suggestions(
        for query: String,
        entries: [CatalogEntry],
        activeCollectionNames: Set<String>,
        selectedCollectionName: String?,
        existingEpisodeNumbersByCollection: [String: Set<Int>],
        limit: Int = 10
    ) -> [CatalogEntry] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= 2 else { return [] }

        let selectedKey = selectedCollectionName.map(normalizedKey)
        if let selectedKey, !activeCollectionNames.contains(selectedKey) {
            return []
        }

        var seenEntryKeys = Set<String>()
        return entries
            .filter { entry in
                guard let collectionName = entry.collectionName else { return false }
                let collectionKey = normalizedKey(collectionName)
                guard activeCollectionNames.contains(collectionKey) else { return false }
                if let selectedKey, collectionKey != selectedKey { return false }
                guard !existingEpisodeNumbersByCollection[collectionKey, default: []].contains(entry.number) else {
                    return false
                }
                return entry.title.localizedCaseInsensitiveContains(normalizedQuery)
            }
            .sorted {
                let leftCollection = $0.collectionName ?? ""
                let rightCollection = $1.collectionName ?? ""
                if leftCollection != rightCollection {
                    return leftCollection.localizedStandardCompare(rightCollection) == .orderedAscending
                }
                return $0.number < $1.number
            }
            .filter { entry in
                let key = "\(normalizedKey(entry.collectionName ?? ""))#\(entry.number)"
                return seenEntryKeys.insert(key).inserted
            }
            .prefix(limit)
            .map { $0 }
    }

    nonisolated static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
