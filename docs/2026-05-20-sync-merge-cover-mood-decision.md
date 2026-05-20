# Entscheidung: Defensive Merge-Logik fuer Cover und Stimmungen

Datum: 2026-05-20

## Kontext

Beim Upgrade von Store-Version 1.5 auf 1.6 wurden lokal angelegte Folgen mit Cover-Screenshots nicht robust genug in den Cloud-Bestand uebernommen. Beobachtet wurde:

- lokale Cover konnten nach dem Upgrade fehlen
- eine Stimmung konnte auf einer Folge erscheinen, die lokal keine Stimmung hatte
- in der Folgenliste fehlte sichtbar Abstand zwischen Cover und Text

Die Ursache liegt nicht in einem einzelnen UI-Problem, sondern im Zusammenspiel aus lokaler Migration, Cloud-Merge und Deduplizierung. In Version 1.5 existierten fuer Cover und Stimmungen noch keine eigenen Aenderungszeitpunkte. Dadurch war unklar, welche Seite bei einem Konflikt die Datenhoheit hat.

## Entscheidung

Die Merge-Strategie wird bewusst defensiv:

- Lokale Daten aus der Upgrade-Migration gewinnen, wenn keine belastbaren Feld-Zeitstempel vorliegen.
- Cloud-Daten gewinnen fuer Cover oder Stimmungen nur dann, wenn beide Seiten fuer genau dieses Feld einen Zeitstempel haben und Cloud wirklich neuer ist.
- Cover und Stimmungen werden getrennt entschieden. Eine neuere Stimmung darf kein Cover ueberschreiben, und ein neueres Cover darf keine Stimmung ueberschreiben.
- Deduplizierung darf keine Stimmungen aus Duplikaten erfinden.
- Ein Cover wird bei Deduplizierung nur uebernommen, wenn die referenzierte lokale Cover-Datei wirklich existiert.
- Bereits abgeschlossene fehlerhafte Migrationen bekommen eine einmalige V5-Reparaturpruefung, die nur fehlende lokale Cover auf vorhandenen Cloud-Folgen ergaenzt. Sie loescht keine Cloud-Folgen und entfernt keine Cloud-Stimmungen.

## Umsetzung

- `Episode` erhaelt `coverUpdatedAt` und `moodsUpdatedAt`.
- Schema wird auf `SchemaV5` angehoben; `SchemaV4` bleibt als historische Version ohne die neuen Zeitstempel erhalten.
- `LocalLibrarySnapshot.EpisodeRecord` nimmt `coverImageName`, `coverUpdatedAt` und `moodsUpdatedAt` mit.
- `SyncMigrationEpisodeMerger` entscheidet Cover und Stimmungen feldweise.
- `EntityDeduplicator` bevorzugt Folgen mit existierender Cover-Datei und fuehrt Stimmungen nicht mehr zusammen.
- `EpisodeCoverManager` setzt `coverUpdatedAt` beim Ersetzen oder Entfernen eines Covers.
- `EpisodeEditView` setzt `moodsUpdatedAt`, wenn sich die Stimmungsauswahl wirklich aendert.
- `AppDataBootstrapper` fuehrt nach einem Upgrade auf V5 eine einmalige Reparaturpruefung fuer bereits abgeschlossene lokale Cloud-Migrationen aus.
- `EpisodeListView` setzt wieder expliziten Abstand zwischen Cover und Text.

## Bewusst nicht getan

- Keine vollautomatische Entfernung bereits vorhandener Cloud-Stimmungen. Das waere fuer den beobachteten Fehler verlockend, koennte aber echte spaetere Cloud-Aenderungen loeschen.
- Keine vollstaendige erneute Migration nach abgeschlossenem Marker. Das waere zu breit und koennte alte lokale Werte ueber juengere Cloud-Arbeit legen.
- Keine Bilddatei-Synchronisation zwischen Geraeten. Die aktuelle Reparatur staerkt die Datenreferenz; echte multi-device Cover-Dateisynchronisation bleibt ein eigener Baustein.

## Tests

Abgedeckt sind:

- lokale Cover werden im Snapshot erfasst
- lokale Felder gewinnen ohne Zeitstempel
- Cloud gewinnt nur mit neueren Feld-Zeitstempeln
- Deduplizierung bevorzugt existierende Cover-Dateien
- Deduplizierung erfindet keine Stimmung
- V5-Schema und sichere Defaults
- einmalige V5-Reparatur ergaenzt fehlende Cover nach abgeschlossenem Migrationsmarker
- UI-Abstand zwischen Bild und Text

Verifikation:

```sh
xcodebuild -project EpisodeTracker.xcodeproj -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 17' clean test
```

Stand vor der V5-Reparatur: erfolgreich.

Nach der V5-Reparatur wurden Build und die gezielten Risiko-Tests erneut ausgefuehrt:

```sh
xcodebuild -project EpisodeTracker.xcodeproj -scheme EpisodeTracker -destination 'generic/platform=iOS Simulator' build
xcodebuild -project EpisodeTracker.xcodeproj -scheme EpisodeTracker -destination 'platform=iOS Simulator,name=iPhone 17' test \
  -only-testing:EpisodeTrackerTests/EpisodeTrackerTests/testBootstrapRepairsMissingCoverAfterCompletedMigrationMarker \
  -only-testing:EpisodeTrackerTests/EpisodeTrackerTests/testBootstrapAutomaticallyMergesLocalDataIntoExistingCloudEpisode \
  -only-testing:EpisodeTrackerTests/EpisodeTrackerTests/testSyncMigrationEpisodeMergerKeepsLocalFieldsWhenTimestampsAreMissing \
  -only-testing:EpisodeTrackerTests/MigrationSafetyTests/testDeduplicationDoesNotInventMoodWhenCoverEpisodeHadNone \
  -only-testing:EpisodeTrackerTests/MigrationSafetyTests/testDeduplicationKeepsCoverWhoseFileStillExists
```

Ergebnis: Build erfolgreich, gezielte Tests erfolgreich.

## Rest-Risiken

- Bereits falsch gesetzte Cloud-Stimmungen werden aus Datensicherheitsgruenden nicht automatisch geloescht.
- Cover-Dateien selbst sind weiterhin lokale Dateien. Wenn ein anderes Geraet nur den Namen, aber nicht die Datei hat, braucht es spaeter eine echte Asset-/Dateisynchronisation.
- Konflikte zwischen iPhone und iPad werden fuer Cover und Stimmungen ab V5 robuster geloest, aber Altwerte ohne Zeitstempel bleiben absichtlich lokal-favorisiert.
