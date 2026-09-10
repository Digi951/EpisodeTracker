import Foundation

/// Device-local choice of which catalog languages are shown in "Reihen
/// auswählen". Never synced (V1.18 Paket 3, §5) — a plain `UserDefaults` string
/// array under `catalogLanguageFilter`.
///
/// - **key absent** ⇒ implicit default `{ app language }`. This is exactly the
///   set the pre-P3-D hard `.matchesDeviceLanguage` filter produced, so the
///   visible sources are unchanged until the user picks something (acceptance
///   criterion 4).
/// - **key present** (a string array, possibly empty) ⇒ an explicit choice that
///   must survive a UI-language change. An explicit *empty* selection is
///   deliberately allowed; the UI then offers "Weitere Sprachen".
///
/// Shape mirrors `ActiveCatalogStore`: a value type with an injectable
/// `UserDefaults` so tests run against an isolated suite.
struct CatalogLanguageFilterStore {
    static let key = "catalogLanguageFilter"

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    /// The raw stored choice, or `nil` when the user has never chosen. Callers
    /// that need to distinguish "never chosen" from "chose nothing" read this;
    /// everyone else reads `selectedLanguages`.
    var explicitSelection: Set<String>? {
        guard let stored = defaults.stringArray(forKey: Self.key) else { return nil }
        return Set(stored.map { $0.lowercased() })
    }

    /// `true` once the user has made any choice (including an empty one).
    var hasExplicitSelection: Bool {
        defaults.stringArray(forKey: Self.key) != nil
    }

    /// The language set to filter `visibleSources` by. Falls back to the app
    /// language while no explicit choice exists.
    var selectedLanguages: Set<String> {
        explicitSelection ?? [ManagedCatalogSource.deviceLanguage]
    }

    /// Persists an explicit choice (an empty set is valid) and invalidates the
    /// registry's language-filtered cache so the next read reflects it.
    func setSelected(_ languages: Set<String>) {
        defaults.set(languages.map { $0.lowercased() }.sorted(), forKey: Self.key)
        CatalogSourceRegistry.invalidateVisibleSourcesCache()
    }

    /// Drops back to the implicit `{ app language }` default.
    func clearSelection() {
        defaults.removeObject(forKey: Self.key)
        CatalogSourceRegistry.invalidateVisibleSourcesCache()
    }
}
