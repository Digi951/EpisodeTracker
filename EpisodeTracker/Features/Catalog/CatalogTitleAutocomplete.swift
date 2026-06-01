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

        let selectedKey = selectedCollectionName.map { CatalogLibraryMatcher.normalizedCollectionKey($0) }
        if let selectedKey, !activeCollectionNames.contains(selectedKey) {
            return []
        }

        var seenEntryKeys = Set<String>()
        return entries
            .filter { entry in
                guard let collectionName = entry.collectionName else { return false }
                let collectionKey = CatalogLibraryMatcher.normalizedCollectionKey(collectionName)
                guard activeCollectionNames.contains(collectionKey) else { return false }
                if let selectedKey, collectionKey != selectedKey { return false }
                let alreadyInLibraryByNumber = entry.number.map {
                    existingEpisodeNumbersByCollection[collectionKey, default: []].contains($0)
                } ?? false
                guard !alreadyInLibraryByNumber else {
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
                return ($0.number ?? 0) < ($1.number ?? 0)
            }
            .filter { entry in
                let identity = entry.number.map(String.init) ?? "special:\(entry.slug ?? entry.title)"
                let key = "\(CatalogLibraryMatcher.normalizedCollectionKey(entry.collectionName ?? ""))#\(identity)"
                return seenEntryKeys.insert(key).inserted
            }
            .prefix(limit)
            .map { $0 }
    }
}
