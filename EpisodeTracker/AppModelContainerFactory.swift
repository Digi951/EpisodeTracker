import Foundation
import SwiftData

enum AppModelContainerMode: Equatable {
    case previewInMemory
    case localPersistent
}

enum AppModelContainerFactory {
    static func schema() -> Schema {
        Schema([
            Episode.self,
            Mood.self,
            Universe.self,
        ])
    }

    static func resolveMode(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppModelContainerMode {
        let isPreviewProcess =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"

        return isPreviewProcess ? .previewInMemory : .localPersistent
    }

    static func makeSharedContainer(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> ModelContainer {
        let schema = schema()

        switch resolveMode(environment: environment) {
        case .previewInMemory:
            return makeInMemoryContainer(schema: schema)
        case .localPersistent:
            return makePersistentContainer(schema: schema, fileManager: fileManager)
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

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }
}
