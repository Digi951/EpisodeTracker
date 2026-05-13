import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.digi.episodetracker"
    static let snapshotFileName = "widget-library-snapshot.json"
    private static let randomRefreshTokenPrefix = "widget-random-refresh-token."

    static func load() -> WidgetLibrarySnapshot? {
        guard let fileURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFileName),
              let data = try? Data(contentsOf: fileURL)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetLibrarySnapshot.self, from: data)
    }

    static func randomRefreshToken(for catalogID: String?) -> Int {
        sharedDefaults?.integer(forKey: refreshTokenKey(for: catalogID)) ?? 0
    }

    static func bumpRandomRefreshToken(for catalogID: String?) {
        let key = refreshTokenKey(for: catalogID)
        let nextValue = (sharedDefaults?.integer(forKey: key) ?? 0) + 1
        sharedDefaults?.set(nextValue, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static func refreshTokenKey(for catalogID: String?) -> String {
        randomRefreshTokenPrefix + (catalogID ?? WidgetCatalogSelection.allValue)
    }
}
