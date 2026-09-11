import Foundation

/// Dauerhafter lokaler Neuigkeiten-Store, JSON-basiert analog `CatalogCacheStore`
/// (Datenvertrag Paket 4 §2 Scope-Entscheidung S1).
///
/// Bewusst eine eigene Datei statt eines SwiftData-`@Model`: ein beschädigter
/// Neuigkeiten-Store darf die Episoden-/Sammlungs-Bibliothek unter keinen
/// Umständen gefährden. `load()` liefert deshalb bei fehlender oder kaputter
/// Datei immer ein leeres, frisches Dokument statt zu werfen.
struct NewsStore {
    private let storeURL: URL
    private let fileManager: FileManager

    // `load()` wird aus mehreren View-Bodies (Ungesehen-Badges in
    // EpisodeListView/IPadEpisodeListView/UpNextView, NewsOverviewView) sehr
    // häufig gelesen; ohne Cache bedeutet jeder Zugriff einen Datei-Read plus
    // JSON-Decode auf dem Main-Thread bei jedem Re-Render (Review-Fund #7).
    // Nach `storeURL` geschlüsselt, damit Tests mit eigenem `directoryURL`
    // sich nicht gegenseitig über den Cache verunreinigen. Einziger
    // Schreibpfad ist `save`, das den Eintrag hier direkt mit aktualisiert —
    // eine separate Invalidierung ist nicht nötig.
    private static let cacheLock = NSLock()
    private static var cachedDocumentsByURL: [URL: NewsStoreDocument] = [:]

    init(fileManager: FileManager = .default) {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        let directoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        self.init(directoryURL: directoryURL, fileManager: fileManager)
    }

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        storeURL = directoryURL.appendingPathComponent("NewsEvents.json")
    }

    /// Liefert nie einen Fehler: fehlt die Datei oder ist sie beschädigt,
    /// kommt ein leeres, frisches Dokument zurück (Baseline läuft dann beim
    /// nächsten Reconcile ganz normal an).
    func load() -> NewsStoreDocument {
        Self.cacheLock.lock()
        if let cached = Self.cachedDocumentsByURL[storeURL] {
            Self.cacheLock.unlock()
            return cached
        }
        Self.cacheLock.unlock()

        let loaded: NewsStoreDocument
        if let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode(NewsStoreDocument.self, from: data) {
            loaded = decoded
        } else {
            loaded = NewsStoreDocument()
        }

        Self.cacheLock.lock()
        Self.cachedDocumentsByURL[storeURL] = loaded
        Self.cacheLock.unlock()
        return loaded
    }

    func save(_ document: NewsStoreDocument) throws {
        let data = try JSONEncoder().encode(document)
        try data.write(to: storeURL, options: [.atomic])

        Self.cacheLock.lock()
        Self.cachedDocumentsByURL[storeURL] = document
        Self.cacheLock.unlock()
    }
}
