import SwiftData

enum EpisodeDeleteHelper {
    static func delete(_ episode: Episode, from context: ModelContext) {
        delete([episode], from: context)
    }

    static func delete(_ episodes: [Episode], from context: ModelContext) {
        let coverNames = episodes.compactMap(\.coverImageName)
        for episode in episodes {
            context.delete(episode)
        }

        do {
            try context.save()
            deleteCoverFiles(named: coverNames)
        } catch {
            context.rollback()
        }
    }

    private static func deleteCoverFiles(named coverNames: [String]) {
        let store = CoverImageStore()
        for coverName in coverNames {
            try? store.delete(name: coverName)
            Task { @MainActor in
                CoverImageCache.shared.removeImage(named: coverName)
            }
        }
    }
}
