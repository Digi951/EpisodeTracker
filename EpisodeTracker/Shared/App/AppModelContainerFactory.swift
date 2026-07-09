import Foundation
import os.log
import SwiftData

enum AppModelContainerMode: Equatable {
    case previewInMemory
    case demo
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
        case .demo:
            "Demo"
        case .localPersistent:
            "Lokal"
        case .cloudPersistent:
            "Cloud"
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
    private static let log = Logger(subsystem: "com.Digi.EpisodeTracker", category: "ModelContainer")

    static let cloudSyncPreferenceKey = "prefersICloudSync"
    static let cloudSyncGuardEnvironmentKey = "EPISODETRACKER_ENABLE_ICLOUD_SYNC"
    static let legacyCloudSyncGuardEnvironmentKey = "EPISODETRACKER_ENABLE_ICLOUD_SYNC_POC"
    static let cloudContainerIdentifier = "iCloud.com.Digi.EpisodeTracker"
    static let appGroupIdentifier = "group.com.digi.episodetracker"
    static let runtimeModeDebugTitleKey = "syncRuntimeModeDebugTitle"
    static let cloudStartupErrorKey = "syncCloudStartupError"
    // Store-recovery diagnostics. Recorded on-device only and never transmitted,
    // so the developer can ask an affected user to read it out of Settings without
    // needing access to the device's crash logs.
    static let storeRecoveryOutcomeKey = "storeRecoveryOutcome"
    static let storeRecoveryTimestampKey = "storeRecoveryTimestamp"
    static let storeRecoveryDetailKey = "storeRecoveryDetail"

    enum StoreRecoveryOutcome: String {
        /// The staged migration failed but a plan-less lightweight open succeeded;
        /// the user's data was preserved.
        case recoveredLightweight
        /// The store could not be opened at all; it was quarantined (kept on disk)
        /// and the app started with a fresh store.
        case quarantinedAndReset

        var localizedTitle: String {
            switch self {
            case .recoveredLightweight:
                return "Datenbank automatisch repariert (Daten erhalten)"
            case .quarantinedAndReset:
                return "Unlesbare Datenbank beiseitegelegt, leer gestartet"
            }
        }
    }

    struct StoreRecoveryRecord: Equatable {
        let outcome: StoreRecoveryOutcome
        let date: Date
        let detail: String
    }

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
        let rawValue = (
            environment[cloudSyncGuardEnvironmentKey]
            ?? environment[legacyCloudSyncGuardEnvironmentKey]
        )?
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
        let localPersistentContainer = makePersistentContainer(
            schema: schema,
            fileManager: fileManager,
            userDefaults: userDefaults
        )

        switch resolveMode(environment: environment, userDefaults: userDefaults) {
        case .demo:
            fatalError("resolveMode() never returns .demo — demo mode is constructed via DemoDataProvider before this factory runs.")
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
        fileManager: FileManager,
        userDefaults: UserDefaults = .standard
    ) -> ModelContainer {
        let storeURL = persistentStoreURL(fileManager: fileManager)
        let storeDirectoryURL = storeURL.deletingLastPathComponent()

        try? fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)
        createPreMigrationBackupIfNeeded(fileManager: fileManager)

        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)

        // 1. Primary path: staged migration through the versioned schema plan.
        let stagedError: Error
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: EpisodeTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            stagedError = error
            log.error("Staged migration failed for \(storeURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
        }

        // 2. Recovery: open without the migration plan so SwiftData can attempt
        //    automatic lightweight inference. This rescues stores the staged
        //    migration cannot identify while preserving the user's data.
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            log.notice("Recovered persistent store via plan-less lightweight migration.")
            recordStoreRecovery(.recoveredLightweight, detail: String(describing: stagedError), userDefaults: userDefaults)
            return container
        } catch {
            log.error("Plan-less recovery failed: \(String(describing: error), privacy: .public)")
        }

        // 3. Last resort: quarantine the unreadable store (kept on disk for a later
        //    salvage attempt, never deleted) and start fresh so the app can launch
        //    instead of hard-crashing on a store it cannot open.
        quarantineUnreadableStore(storeURL: storeURL, fileManager: fileManager)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            log.notice("Started with a fresh store after quarantining an unreadable store.")
            recordStoreRecovery(.quarantinedAndReset, detail: String(describing: stagedError), userDefaults: userDefaults)
            return container
        } catch {
#if DEBUG
            return makeInMemoryContainer(schema: schema)
#else
            // A fresh store that still cannot be created points at a non-recoverable
            // environment problem (e.g. no writable Application Support directory),
            // not at the user's data.
            fatalError("Could not create a fresh persistent ModelContainer at \(storeURL.path): \(error)")
#endif
        }
    }

    /// Moves a store that cannot be opened (and its sidecar files) aside so the app
    /// can start with a fresh store. The quarantined files are preserved on disk for
    /// a potential future salvage; they are only removed if they cannot be moved.
    static func quarantineUnreadableStore(storeURL: URL, fileManager: FileManager) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let quarantineBase = storeURL.deletingPathExtension()
            .appendingPathExtension("unreadable-\(timestamp)")
            .appendingPathExtension("store")

        let sidecarSuffixes = ["", "-wal", "-shm"]
        for suffix in sidecarSuffixes {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }

            let destination = URL(fileURLWithPath: quarantineBase.path + suffix)
            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch {
                log.error("Could not quarantine \(source.lastPathComponent, privacy: .public), removing it: \(String(describing: error), privacy: .public)")
                try? fileManager.removeItem(at: source)
            }
        }
    }

    /// Records that the persistent store had to be recovered at launch. Stored only
    /// in local defaults so it can be surfaced in Settings; never transmitted.
    static func recordStoreRecovery(
        _ outcome: StoreRecoveryOutcome,
        detail: String,
        date: Date = .now,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(outcome.rawValue, forKey: storeRecoveryOutcomeKey)
        userDefaults.set(date.timeIntervalSince1970, forKey: storeRecoveryTimestampKey)
        userDefaults.set(String(detail.prefix(500)), forKey: storeRecoveryDetailKey)
    }

    /// The most recent store-recovery event, or `nil` if the store has always opened
    /// normally on this device.
    static func lastStoreRecovery(userDefaults: UserDefaults = .standard) -> StoreRecoveryRecord? {
        guard
            let rawValue = userDefaults.string(forKey: storeRecoveryOutcomeKey),
            let outcome = StoreRecoveryOutcome(rawValue: rawValue)
        else {
            return nil
        }
        return StoreRecoveryRecord(
            outcome: outcome,
            date: Date(timeIntervalSince1970: userDefaults.double(forKey: storeRecoveryTimestampKey)),
            detail: userDefaults.string(forKey: storeRecoveryDetailKey) ?? ""
        )
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
