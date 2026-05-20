import UIKit

enum EpisodeCoverChange {
    case keep
    case remove
    case replace(UIImage)
}

struct EpisodeCoverManager {
    private let store: CoverImageStore
    private let cache: CoverImageCache

    @MainActor
    init() {
        self.store = CoverImageStore()
        self.cache = .shared
    }

    @MainActor
    init(store: CoverImageStore, cache: CoverImageCache) {
        self.store = store
        self.cache = cache
    }

    @MainActor
    func apply(_ change: EpisodeCoverChange, to episode: Episode) throws {
        let coverName = CoverImageStore.coverName(for: episode.id)

        switch change {
        case .keep:
            return
        case .remove:
            try store.delete(name: coverName)
            cache.removeImage(named: coverName)
            episode.coverImageName = nil
        case .replace(let image):
            try store.save(image, name: coverName)
            cache.removeImage(named: coverName)
            episode.coverImageName = coverName
        }
    }
}
