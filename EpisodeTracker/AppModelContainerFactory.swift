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

struct AppModelContainerSet {
    let primary: ModelContainer
    let localPersistent: ModelContainer?
    let cloudPersistent: ModelContainer?
    let runtimeMode: AppModelContainerMode
}

enum AppModelContainerFactory {
    static let cloudSyncPreferenceKey = "prefersICloudSync"
    static let cloudSyncGuardEnvironmentKey = "EPISODETRACKER_ENABLE_ICLOUD_SYNC_POC"
    static let cloudContainerIdentifier = "iCloud.com.Digi.EpisodeTracker"
    static let appGroupIdentifier = "group.com.digi.episodetracker"
    static let runtimeModeDebugTitleKey = "syncRuntimeModeDebugTitle"
    static let cloudStartupErrorKey = "syncCloudStartupError"

    private enum CloudStartupPreflightError: LocalizedError {
        case missingICloudAccount
        case missingAppGroupContainer
        case appGroupApplicationSupportCreationFailed(URL, Error)

        var errorDescription: String? {
            switch self {
            case .missingICloudAccount:
                return "Kein aktiver iCloud-Account verfügbar. Cloud-Sync bleibt lokal, bis iCloud auf diesem Gerät verfügbar ist."
            case .missingAppGroupContainer:
                return "Der App-Group-Container ist nicht verfügbar. Cloud-Sync kann den gemeinsamen Store-Pfad nicht vorbereiten."
            case .appGroupApplicationSupportCreationFailed(let url, let error):
                return "Der App-Group-Application-Support-Ordner konnte nicht vorbereitet werden: \(url.path) - \(error.localizedDescription)"
            }
        }
    }

    static func schema() -> Schema {
        Schema([Episode.self, Mood.self, Universe.self])
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

        if userDefaults.bool(forKey: cloudSyncPreferenceKey),
           isCloudSyncGuardEnabled(environment: environment) {
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

    static func showsInternalSyncControls(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
#if DEBUG
        let isPreviewProcess =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"

        #if targetEnvironment(simulator)
        return true
        #else
        return isPreviewProcess
        #endif
#else
        return false
#endif
    }

    static func makeSharedContainer(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) -> ModelContainer {
        makeSharedContainerSet(
            environment: environment,
            fileManager: fileManager,
            userDefaults: userDefaults
        ).primary
    }

    static func makeSharedContainerSet(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) -> AppModelContainerSet {
        let schema = schema()
        let localPersistentContainer = makePersistentContainer(schema: schema, fileManager: fileManager)

        switch resolveMode(environment: environment, userDefaults: userDefaults) {
        case .previewInMemory:
            recordRuntimeMode(.previewInMemory, userDefaults: userDefaults)
            return AppModelContainerSet(
                primary: makeInMemoryContainer(schema: schema),
                localPersistent: nil,
                cloudPersistent: nil,
                runtimeMode: .previewInMemory
            )
        case .localPersistent:
            recordRuntimeMode(.localPersistent, userDefaults: userDefaults)
            return AppModelContainerSet(
                primary: localPersistentContainer,
                localPersistent: localPersistentContainer,
                cloudPersistent: nil,
                runtimeMode: .localPersistent
            )
        case .cloudPersistent(let containerIdentifier):
            guard isICloudIdentityAvailable(fileManager: fileManager) else {
#if DEBUG
                recordRuntimeMode(
                    .localPersistent,
                    cloudStartupError: CloudStartupPreflightError.missingICloudAccount,
                    userDefaults: userDefaults
                )
                return AppModelContainerSet(
                    primary: localPersistentContainer,
                    localPersistent: localPersistentContainer,
                    cloudPersistent: nil,
                    runtimeMode: .localPersistent
                )
#else
                recordRuntimeMode(.localPersistent, userDefaults: userDefaults)
                return AppModelContainerSet(
                    primary: localPersistentContainer,
                    localPersistent: localPersistentContainer,
                    cloudPersistent: nil,
                    runtimeMode: .localPersistent
                )
#endif
            }

            do {
                let cloudContainer = try makeCloudContainer(
                    schema: schema,
                    fileManager: fileManager,
                    containerIdentifier: containerIdentifier
                )
                recordRuntimeMode(
                    .cloudPersistent(containerIdentifier: containerIdentifier),
                    userDefaults: userDefaults
                )
                return AppModelContainerSet(
                    primary: cloudContainer,
                    localPersistent: localPersistentContainer,
                    cloudPersistent: cloudContainer,
                    runtimeMode: .cloudPersistent(containerIdentifier: containerIdentifier)
                )
            } catch {
#if DEBUG
                recordRuntimeMode(
                    .localPersistent,
                    cloudStartupError: error,
                    userDefaults: userDefaults
                )
                return AppModelContainerSet(
                    primary: localPersistentContainer,
                    localPersistent: localPersistentContainer,
                    cloudPersistent: nil,
                    runtimeMode: .localPersistent
                )
#else
                fatalError("Could not create CloudKit ModelContainer for \(containerIdentifier): \(error)")
#endif
            }
        }
    }

    static func persistentStoreURL(fileManager: FileManager = .default) -> URL {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        let storeDirectoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        return storeDirectoryURL.appendingPathComponent("EpisodeTracker.store")
    }

    static func appGroupApplicationSupportDirectoryURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
    }

    static func isICloudIdentityAvailable(fileManager: FileManager = .default) -> Bool {
        fileManager.ubiquityIdentityToken != nil
    }

    static func createPreMigrationBackupIfNeeded(fileManager: FileManager = .default) {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: storeURL.path) else { return }

        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("EpisodeTracker.pre-migration-backup.store")
        guard !fileManager.fileExists(atPath: backupURL.path) else { return }

        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let source = URL(fileURLWithPath: storeURL.path + ext)
            let destination = URL(fileURLWithPath: backupURL.path + ext)
            try? fileManager.copyItem(at: source, to: destination)
        }
    }

    static func removePreMigrationBackup(fileManager: FileManager = .default) {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        let backupURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("EpisodeTracker.pre-migration-backup.store")

        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let path = backupURL.path + ext
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }

    private static func makePersistentContainer(
        schema: Schema,
        fileManager: FileManager
    ) -> ModelContainer {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        let storeDirectoryURL = storeURL.deletingLastPathComponent()

        try? fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)
        createPreMigrationBackupIfNeeded(fileManager: fileManager)

        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: EpisodeTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
#if DEBUG
            return makeInMemoryContainer(schema: schema)
#else
            fatalError("Could not create persistent ModelContainer at \(storeURL.path): \(error)")
#endif
        }
    }

    private static func makeCloudContainer(
        schema: Schema,
        fileManager: FileManager,
        containerIdentifier: String
    ) throws -> ModelContainer {
        try prepareAppGroupApplicationSupportDirectory(fileManager: fileManager)

        let configuration = ModelConfiguration(
            "Default",
            schema: schema,
            cloudKitDatabase: .automatic
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: EpisodeTrackerMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private static func prepareAppGroupApplicationSupportDirectory(fileManager: FileManager) throws {
        guard let appGroupApplicationSupportURL = appGroupApplicationSupportDirectoryURL(fileManager: fileManager) else {
            throw CloudStartupPreflightError.missingAppGroupContainer
        }

        do {
            try fileManager.createDirectory(
                at: appGroupApplicationSupportURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw CloudStartupPreflightError.appGroupApplicationSupportCreationFailed(
                appGroupApplicationSupportURL,
                error
            )
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

    private static func recordRuntimeMode(
        _ mode: AppModelContainerMode,
        cloudStartupError: Error? = nil,
        userDefaults: UserDefaults
    ) {
        userDefaults.set(mode.debugTitle, forKey: runtimeModeDebugTitleKey)

        if let cloudStartupError {
            userDefaults.set(String(describing: cloudStartupError), forKey: cloudStartupErrorKey)
        } else {
            userDefaults.removeObject(forKey: cloudStartupErrorKey)
        }
    }
}
