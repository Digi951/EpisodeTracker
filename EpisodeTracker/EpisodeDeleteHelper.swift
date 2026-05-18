import SwiftData

enum EpisodeDeleteHelper {
    static func delete(_ episode: Episode, from context: ModelContext) {
        let store = CoverImageStore()
        if let coverName = episode.coverImageName {
            try? store.delete(name: coverName)
        }
        context.delete(episode)
    }

    static func delete(_ episodes: [Episode], from context: ModelContext) {
        let store = CoverImageStore()
        for episode in episodes {
            if let coverName = episode.coverImageName {
                try? store.delete(name: coverName)
            }
            context.delete(episode)
        }
    }
}
