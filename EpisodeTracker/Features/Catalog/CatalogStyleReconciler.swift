import Foundation

enum CatalogStyleReconciler {
    /// Überträgt den im Manifest deklarierten Katalog-Stil auf die passenden
    /// Sammlungen. Manuell angelegte Sammlungen (kein Manifest-Eintrag mit
    /// gleichem Namen) bleiben unangetastet und damit `numbered`.
    static func reconcile(universes: [Universe], sources: [ManagedCatalogSource]) {
        guard !sources.isEmpty else { return }

        let stylesByName = sources.reduce(into: [String: CatalogStyle]()) { result, source in
            let key = CatalogLibraryMatcher.normalizedCollectionKey(source.name)
            guard !key.isEmpty else { return }
            result[key] = source.effectiveStyle
        }

        for universe in universes {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(universe.name)
            guard let style = stylesByName[key], universe.style != style else { continue }
            universe.style = style
        }
    }
}
