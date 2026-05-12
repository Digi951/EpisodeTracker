import Foundation
import SwiftData

enum AppModelContainerMode: Equatable {
    case previewInMemory
    case localPersistent
    case cloudPersistent(containerIdentifier: String)

    var usesCloudSync: Bool {
        if case .cloudPersistent = self {
            return true
        }
        return false
    }

    var debugTitle: String {
        switch self {
        case .previewInMemory:
            "Preview (In-Memory)"
        case .localPersistent:
            "Lokal"
        case .cloudPersistent:
            "Cloud PoC"
        }
    }
}

enum AppModelContainerFactory {
    static let cloudSyncPreferenceKey = "prefersICloudSync"
    static let cloudSyncGuardEnvironmentKey = "EPISODETRACKER_ENABLE_ICLOUD_SYNC_POC"
    static let cloudContainerIdentifier = "iCloud.com.Digi.EpisodeTracker"

    static func schema() -> Schema {
        Schema([
            Episode.self,
            Mood.self,
            Universe.self,
        ])
    }

    static func resolveMode(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard
    ) -> AppModelContainerMode {
        let isPreviewProcess =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"

        if isPreviewProcess {
            return .previewInMemory
        }

        let prefersICloudSync = userDefaults.bool(forKey: cloudSyncPreferenceKey)
        let cloudSyncGuardEnabled = isCloudSyncGuardEnabled(environment: environment)
        if prefersICloudSync && cloudSyncGuardEnabled {
            return .cloudPersistent(containerIdentifier: cloudContainerIdentifier)
        }

        return .localPersistent
    }

    static func isCloudSyncGuardEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let rawValue = environment[cloudSyncGuardEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
    }

    static func makeSharedContainer(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) -> ModelContainer {
        let schema = schema()

        switch resolveMode(environment: environment, userDefaults: userDefaults) {
        case .previewInMemory:
            return makeInMemoryContainer(schema: schema)
        case .localPersistent:
            return makePersistentContainer(schema: schema, fileManager: fileManager)
        case .cloudPersistent(let containerIdentifier):
            return makeCloudContainer(
                schema: schema,
                fileManager: fileManager,
                containerIdentifier: containerIdentifier
            )
        }
    }

    static func persistentStoreURL(fileManager: FileManager = .default) -> URL {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDirectoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        return storeDirectoryURL.appendingPathComponent("EpisodeTracker.store")
    }

    private static func makePersistentContainer(
        schema: Schema,
        fileManager: FileManager
    ) -> ModelContainer {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        let storeDirectoryURL = storeURL.deletingLastPathComponent()

        try? fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)

        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create persistent ModelContainer at \(storeURL.path): \(error)")
        }
    }

    private static func makeCloudContainer(
        schema: Schema,
        fileManager: FileManager,
        containerIdentifier: String
    ) -> ModelContainer {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        let storeDirectoryURL = storeURL.deletingLastPathComponent()

        try? fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(
            "Default",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(containerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create CloudKit ModelContainer for \(containerIdentifier): \(error)")
        }
    }

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }
}
