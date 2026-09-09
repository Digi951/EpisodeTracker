import Foundation

/// Erzwingt die Anthologie-Invariante auf Eintragsebene beim Katalog-Import:
/// `style: .anthology` ⇒ jede Folge `kind: .special` mit stabilem Slug.
///
/// Gegenstück zu `CatalogStyleReconciler` (der den `style` einer bestehenden
/// `Universe` nachzieht) — dieser Normalizer greift eine Stufe früher, direkt
/// auf den frisch geparsten `CatalogEntry`-Rohdaten, **bevor** `CatalogSnapshot`
/// und Delta gebildet werden, damit `specialSlugs` und das Delta stimmen.
///
/// Bestehende Slugs werden **nie** überschrieben (Sync-Identität, eingefroren);
/// nur fehlende/leere Slugs werden über `SpecialEpisodeSlug.make(...)`
/// deterministisch synthetisiert. `.numbered`-Kataloge bleiben unangetastet.
enum CatalogStyleNormalizer {
    static func normalize(
        _ entries: [CatalogEntry],
        style: CatalogStyle,
        collectionName: String
    ) -> [CatalogEntry] {
        guard style == .anthology else { return entries }

        let universeKey = CatalogLibraryMatcher.normalizedCollectionKey(collectionName)

        return entries.map { entry in
            let hasSlug = entry.slug?.isEmpty == false

            // Schon korrekt eingetütet — nichts anfassen (Slug eingefroren).
            if entry.kind == .special, hasSlug {
                return entry
            }

            let slug = hasSlug
                ? entry.slug!
                : SpecialEpisodeSlug.make(
                    title: entry.title,
                    releaseYear: entry.releaseYear,
                    universeKey: universeKey
                )

            return CatalogEntry(
                number: entry.number,
                kind: .special,
                slug: slug,
                title: entry.title,
                releaseYear: entry.releaseYear,
                collectionName: entry.collectionName,
                links: entry.links
            )
        }
    }
}
