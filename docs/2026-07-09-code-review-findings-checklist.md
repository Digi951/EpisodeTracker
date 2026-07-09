# Code-Review-Findings — Checkliste

Aus dem `/code-review` high-effort-Durchlauf ueber `git diff @{upstream}...HEAD` (2026-07-09). Alle Findings verifiziert (CONFIRMED), noch nicht behoben.

## Kritisch — Datenverlust

- [x] **Demo-Modus loescht echte Cover-Dateien** — `AppDataBootstrapper.swift:401` (`cleanupOrphanedCovers`), ausgeloest von `EpisodeTrackerApp.swift:44-48`
  `cleanupOrphanedCovers` laeuft auch im Demo-Modus, baut `knownCoverNames` aus dem leeren Demo-Container (keine Episode hat ein Cover) und loescht darueber **alle echten** `.jpg`-Dateien im echten `Application Support/EpisodeTracker/covers`-Ordner, weil `CoverImageStore()` immer denselben realen Pfad nutzt, egal welcher Container reingereicht wird. Widerspricht der Settings-Aussage "Echte Daten bleiben unberuehrt".
  **Fix:** neuer `AppModelContainerMode.demo`-Case; `DemoDataProvider` nutzt ihn statt `.previewInMemory`; `AppDataBootstrapper.bootstrap(containerSet:)` gibt fruehzeitig zurueck, wenn `runtimeMode == .demo`.

- [x] **Demo-Modus ueberschreibt Schema-Version + loescht Pre-Migration-Backup** — `AppDataBootstrapper.swift:82-83`
  Gleicher Bootstrap-Pfad schreibt `schemaVersionKey` in `UserDefaults.standard` und ruft `AppModelContainerFactory.removePreMigrationBackup()` — beides wirkt auf den echten, geteilten State, nicht auf den Demo-Container. Entfernt das Migration-Sicherheitsnetz fuer die echten Daten.
  **Fix:** durch denselben Early-Return oben mit erledigt.

## Hoch — sichtbare Bugs

- [x] **Unuebersetzter deutscher Text in der neuen Statistik-Hero-Card** — `StatisticsContentViews.swift:367,378,383`
  `Text("Top-Hörspiel")`, `Text("· \(rating) ⭐")`, `Text("· \(episode.listenCount)× gehört")` nutzen kein `String(localized:defaultValue:)`. In `Localizable.xcstrings` haben die drei Keys keinen `localizations`-Block — englische Nutzer sehen rohen deutschen Text. **Nicht** hinter `#if DEBUG`, betrifft also echte App-Store-Nutzer.
  **Fix:** englische Uebersetzungen fuer die drei bereits automatisch extrahierten Keys in `Localizable.xcstrings` ergaenzt (Code blieb unveraendert, Pattern entspricht anderen unkommentierten `Text(...)`-Strings in derselben Datei, die schon uebersetzt sind).

## Mittel — Demo-Modus-Bugs (DEBUG-only)

- [x] **Demo-Seeding schluckt Fehler still** — `DemoDataProvider.swift:113`
  `try? context.save()` ohne Fehlerbehandlung — bei einem SwiftData-Validierungsfehler bleibt der Demo-Modus stillschweigend leer, kein Log wie sonst ueberall via `bootstrapLogger`.
  **Fix:** `do/catch` mit `Logger`-Fehlermeldung (analog `bootstrapLogger` in `AppDataBootstrapper`).

- [x] **Demo-Container faelschlich als `.previewInMemory` markiert** — `EpisodeTrackerApp.swift:20`
  Verwechselt Demo-Session mit SwiftUI-Preview in allem, was `containerSet.runtimeMode` auswertet (z.B. Sync-Diagnose in den Settings).
  **Fix:** durch den neuen `.demo`-Case oben mit erledigt.

- [x] **Demo-Modus fuegt leere echte Kataloge + "Allgemein" in die fiktive Demo-Bibliothek ein** — `AppDataBootstrapper.swift:352` (`ensureBundledCollectionExists`/`assignMissingCollectionsIfNeeded`)
  Diese Funktionen kennen keinen Demo-Modus und vergleichen gegen die echten Katalognamen — bei den bewusst fiktiven Demo-Namen ("Die drei Detektive" etc.) matcht nichts, es entstehen leere Zusatz-Kataloge in der Uebersicht.
  **Fix:** durch den Bootstrap-Early-Return oben mit erledigt (diese Funktionen laufen im Demo-Modus jetzt gar nicht mehr).

## Niedrig — Wartbarkeit / Konsistenz

- [x] **AppStorage-Key doppelt als String-Literal statt Konstante** — `SettingsView.swift:1147`
  `@AppStorage("isDemoModeActive")` statt `DemoDataProvider.userDefaultsKey` — bei kuenftiger Umbenennung faellt der Settings-Schalter lautlos aus der Kopplung.
  **Fix:** nutzt jetzt `DemoDataProvider.userDefaultsKey`.

- [x] **Neue `StatisticsHeroCard` umgeht das Sektionen-Anpassen-System** — `StatisticsContentViews.swift:14`
  Wird fest vor `ForEach(visibleSections)` gerendert statt als `StatisticsSectionKind`-Case — Nutzer koennen sie nicht wie alle anderen Statistik-Sektionen ein-/ausblenden oder umsortieren.
  **Fix:** neuer `.hero`-Case in `StatisticsSectionKind`, Hero-Card wird jetzt im `switch section`-Block gerendert (iPhone + iPad).

- [ ] **`StatCard` dupliziert `StatSummaryTile`** — `StatisticsContentViews.swift:416` vs. `:205`
  Zwei fast identische Kachel-Designs fuer dieselben Daten (iPhone nutzt `StatCard`, iPad weiterhin `StatSummaryTile`) — sehen bereits jetzt unterschiedlich aus und laufen bei kuenftigen Anpassungen auseinander.
  **Bewusst nicht gemerged:** ein Merge wuerde eine Design-Entscheidung treffen (welches Aussehen gewinnt auf welcher Plattform), die nicht Teil dieses Fixes ist. Stattdessen mit `ponytail:`-Kommentar an beiden Stellen als bewusste Trennung markiert.

- [x] **`StatisticsSnapshot` wird pro Render ~15x neu berechnet** — `StatisticsView.swift:13`
  `statistics` ist eine ungecachte computed property; dieser Diff haengt zwei weitere teure Operationen (Sort + Dictionary-Aufbau) daran, die bei jedem der ~15 Zugriffe pro Render erneut laufen.
  **Fix:** `statistics` und `availableOverviewItems` werden jetzt einmal pro `body`-Aufruf berechnet und als Parameter durchgereicht statt als computed properties erneut ausgewertet zu werden.

## Vorschlag Reihenfolge

1. Beide Demo-Modus-Datenverlust-Punkte zusammen fixen (gleiche Root Cause: Bootstrap laeuft unveraendert auf dem Demo-Container) — z.B. `bootstrap` fruehzeitig returnen, wenn `runtimeMode == .demo` (neuer eigener Case statt `.previewInMemory`, loest damit auch Punkt 5).
2. Uebersetzung der Hero-Card-Strings nachtragen (schnell, sichtbarer Nutzeffekt).
3. Rest nach Zeitbudget.
