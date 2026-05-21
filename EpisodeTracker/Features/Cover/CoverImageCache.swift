import UIKit

@MainActor
final class CoverImageCache {
    static let shared = CoverImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(named name: String) -> UIImage? {
        image(named: name, store: CoverImageStore())
    }

    func image(named name: String, store: CoverImageStore) -> UIImage? {
        let key = name as NSString
        if let image = cache.object(forKey: key) {
            return image
        }

        guard let image = store.load(name: name) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    func removeImage(named name: String) {
        cache.removeObject(forKey: name as NSString)
    }
}
