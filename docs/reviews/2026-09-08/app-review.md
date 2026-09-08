# HörspielLog: Kataloge, neue Folgen und Produktentwicklung

Stand: 8. September 2026. Prüfung des lokalen Quellcodes, ausgewählter Tests, öffentlicher Katalogdaten und des Erststarts der installierten Simulator-App. Keine Änderungen am Anwendungscode.

## Ergebnis

Gute Grundlage durch lokalen Cache, bedingte HTTP-Abfragen, Katalog-Manifest, separate Sonderfolgen, Streaming-Verknüpfungen, Smart Lists und den Veröffentlichungskalender. Der größte Verbesserungsbedarf besteht beim verlässlichen Status neuer Inhalte und beim Weg vom Hinweis zur konkreten Aktion.

## Umfang und Grenzen

- Aktueller Screenshot des Erststarts im iPhone-17-Simulator; installierte App-Version nicht mit dem Checkout abgeglichen.
- Kein vollständiger visueller Flow-Audit: Das für interaktive Mac-Bedienung vorgeschriebene `node_repl` ist nicht verfügbar. Weitere Bildschirme, VoiceOver, große Schrift, iPad und reale Touch-Bedienung sind nicht verifiziert. Der Audit-Skill verlangt: „Do not claim an audit if the actual flow could not be accessed and captured.“ Deshalb sind nachfolgende Ablaufbefunde ausdrücklich Code-Review-Ergebnisse.
- 35 bestehende Tests aus EpisodeCatalogTests, UpcomingReleasesFeedTests, CatalogManagementViewTests und CatalogLibraryMatcherTests erfolgreich. Die Management-Tests prüfen überwiegend Beschriftungen, nicht den Aktivierungsablauf. Kein vollständiger Testsuite-Lauf und keine simulierten HTTP-Fehlerszenarien.
- Live geprüft: Manifest, Terminfeed, ein Beispielkatalog, öffentlicher Repository-Dateibaum und Linkprüfskript. Keine vollständige Verifikation sämtlicher Hörspieldaten oder Streaming-Ziele gegen Verlage.

## Schritte der Nutzerreise

1. **Erststart – verständlich, mit sichtbarem Layoutproblem.** Klare Einführung mit drei Schritten. Das schwebende Plus überlagert teilweise „Erste Folge anlegen“; der Fußtext liegt teilweise hinter der Tabbar. Für eine leere Bibliothek genügt eine primäre Hinzufügen-Aktion. Suche und Sortierung bieten hier noch wenig Nutzen. Screenshot: `01-erststart.png`.
2. **Katalog entdecken und aktivieren – funktional unvollständig, nur Code geprüft.** Einstellungen bieten Suche, aktive/verfügbare Kataloge und Aktualisierung. Aktivierung startet keinen Download und zeigt keinen individuellen Ladezustand.
3. **Neue Folge entdecken – Hinweise vorhanden, Aktion fehlt, nur Code geprüft.** Katalogbanner enthalten Text und Schließen, aber keine Navigation zur betroffenen Reihe oder Folge.
4. **Angekündigte Folge ansehen – Kalender vorhanden, Anschluss fehlt, nur Code geprüft.** Termine sind nach Datum sortiert; Vormerken, Erinnern, Details und Streaming-Aktionen fehlen im Sheet.
5. **In Bibliothek übernehmen – für bestehende Reihen unterstützt, nur Code geprüft.** Katalogvorschläge und Sammelimport existieren. Vorschläge setzen jedoch bereits mindestens eine Bibliotheksfolge der Reihe voraus. Eine frisch aktivierte Reihe bleibt dadurch zunächst außerhalb dieses Entdeckungswegs.

## Priorisierte Befunde

### P1: Fehlgeschlagene HTTP-Abfragen werden als geprüft behandelt

`CatalogRemoteDataSource.swift:52`: Alle HTTP-Status außer 200/304 werden `.skipped`. `EpisodeCatalog.swift` behandelt `.skipped` zusammen mit `.notModified` und schreibt `lastCheckedAt`. Dadurch können etwa 404/500 im manuellen Refresh zu „Aktive Kataloge wurden aktualisiert“ führen; der reguläre Refresh kann anschließend sechs Stunden pausieren. Kaltstart und manuelle Aktualisierung umgehen diesen Zeitraum, lösen aber die falsche Erfolgsmeldung nicht.

**Verbesserung:** HTTP-Fehler separat modellieren; letzten Versuch und letzten erfolgreichen Abgleich unterscheiden. Fehler pro Katalog sammeln; Teil-Erfolg anzeigen; vorhandene Daten behalten. Verifikation: 200, 304, 404, 429, 500, Timeout und ungültiges JSON.

### P1: Veröffentlichungsstatus fehlt im normalen Katalog

Live-Beispiel: Die drei ???, Folge 241 „Meister des Lichts“ steht im normalen Katalog; der Terminfeed nennt den 18.09.2026. `CatalogEntry` speichert nur `releaseYear`. Die Vorschlagslogik kann die Folge daher schon vor Veröffentlichung anbieten, ohne ihren Status zu kennen. Vormerken wäre sinnvoll, eine eindeutige Verfügbarkeit fehlt jedoch.

**Verbesserung:** Gemeinsame stabile Folgen-ID, `releaseDate`, Status wie angekündigt/erschienen/verschoben sowie Quellenangabe und Prüfdatum. Normale Katalogdaten und Terminfeed aus derselben gepflegten Grundlage ableiten. Vergangene Termine allein sind noch kein Nachweis einer tatsächlichen Veröffentlichung.

### P1: Aktivieren ist kein sofort nutzbarer Ablauf

`CatalogManagementView.swift:178` setzt aktive IDs und legt gegebenenfalls eine Universe an; kein Fetch. Ein neuer Katalog wird erst bei einem anderen Refresh-Auslöser geladen. `CatalogLibraryMatcher.swift` überspringt Reihen ohne Bibliotheksfolgen.

**Verbesserung:** Beim Aktivieren gezielt laden und anschließend eine Vorschau mit „Folgen auswählen“ zeigen. Die Aktivierung einer Reihe muss für Entdeckung genügen. Nutzer sollten zum Start keine Folgennummer kennen müssen.

### P1: Sprachwechsel kann Abonnements entfernen

`CatalogSourceRegistry.managedSources` filtert nach Gerätesprache. `ActiveCatalogStore.swift:36` verwendet genau diese sprachgefilterte Menge zum Entfernen vermeintlich verwaister IDs. Beim Sprachwechsel können weiterhin verfügbare Reihen als entfernt gelten und aus den aktiven IDs verschwinden. Gespeicherte Bibliotheksfolgen werden damit nicht gelöscht.

**Verbesserung:** Existenzprüfung gegen das vollständige Manifest; Inhaltssprachen unabhängig von der UI-Sprache wählbar machen. Gespeicherte aktive Reihen behalten. Ohne gespeicherte Auswahl sind derzeit alle sichtbaren Kataloge aktiv; eine bewusste Reihenauswahl wäre verständlicher.

### P2: Aktualisierung beim Zurückkehren zur App fehlt

`EpisodeTrackerApp.swift:51` stößt bei Aktivierung nur die Cloud-Sync-Reparatur an. Der Katalog-Refresh erfolgt beim Bootstrap, in der Verwaltung oder gezielt beim Bearbeiten einer Folge. Der Sechs-Stunden-Zeitraum ist eine Abrufsperre, kein regelmäßiger Hintergrundjob.

**Verbesserung:** Beim Wechsel in den Vordergrund gedrosselt aktualisieren, parallele identische Abrufe zusammenführen und eine manuelle Aktualisierung am Neuigkeiten-Bereich anbieten.

### P2: Neuigkeiten sind flüchtig und ohne direkten Zielbildschirm

`CatalogUpdateBannerView.swift`: einzige Button-Aktion ist Schließen. `EpisodeListOrganizer.swift:67` priorisiert neue Kataloge vor Folgen-Deltas. `EpisodeCatalog.swift` überschreibt neue Katalogverfügbarkeit und Folgen-Deltas beim nächsten geänderten Dokument, statt ungesehene Ereignisse dauerhaft zu sammeln. Ein ausgeblendeter priorisierter Banner gibt den darunterliegenden Hinweis nicht automatisch frei.

**Verbesserung:** Dauerhafte Neuigkeitenliste mit stabilen Ereignis-IDs, Gesehen-Status und direkten Aktionen. Erst durch Nutzeraktion als erledigt behandeln. Beispiel: „2 neue Folgen in deinen Reihen“ → genau diese Folgen → hinzufügen oder vormerken.

### P2: Terminänderungen und unbekannte Aktualität bleiben unsichtbar

`UpcomingReleasesFeed.swift:35` entfernt vergangene Termine und behält bei doppelter Folgen-ID das frühere Datum. Bei Verschiebungen kann das der veraltete Termin sein. Gesehen-IDs enthalten kein Änderungsmerkmal; ein verschobener Termin wird daher nicht erneut hervorgehoben. Netzwerkfehler des Feeds bleiben ohne sichtbaren Status. `updatedAt` wird dekodiert, aber nicht als Feed-Aktualität gespeichert/angezeigt.

**Verbesserung:** Maßgeblicher Termin anhand Quellenstand/Änderungsdatum; Terminänderung separat kennzeichnen. „Keine Ankündigungen“ von „Noch nicht geladen“ und „Stand vom …, derzeit offline“ unterscheiden. Neu erschienene Folgen für eine definierte Zeit in einem separaten Abschnitt halten.

## Öffentliche Bereitstellung

Das Manifest enthält 23 Kataloge: 16 deutsche und 7 englische. Der Terminfeed trägt `updatedAt: 2026-09-08` und enthält drei Folgen. Das ist der deklarierte Datenstand, kein unabhängig bestätigter Verlagstermin. Der Beispielkatalog Die drei ??? trägt `lastUpdated: 2026-09-01`; 257 deklarierte Einträge stimmen mit 257 tatsächlichen Einträgen überein, ohne doppelte Schlüssel aus Typ und Nummer/Slug. Das Manifestdatum 21.06.2026 beweist keine veralteten einzelnen Kataloge.

Im abgefragten öffentlichen main-Dateibaum sind keine GitHub-Actions-Workflows oder ein Generator für den Terminfeed enthalten. Eine außerhalb des Repositories laufende Automatisierung kann dennoch existieren. Das vorhandene `scripts/check_catalogs.py` prüft vier historische Streaming-Felder; das App-Modell unterstützt inzwischen auch ein allgemeines `links`-Dictionary. Dieses Format und neue Dienste sollten in die Validierung aufgenommen werden.

Empfohlene Bereitstellungskette:

1. Quellenänderungen erfassen und Quelle/Prüfdatum mitführen.
2. Schema, eindeutige IDs, Datumsformat, Manifest-Verweise, Eintragszahlen und verdächtige Löschungen prüfen.
3. Vorschau erzeugen: neue Folgen, geänderte Termine, neue Reihen, entfernte Einträge.
4. Einen konsistenten Stand veröffentlichen; vorherige Version zur Wiederherstellung behalten.
5. Erfolgreichen Lauf und Datenalter überwachen. App zeigt letzten erfolgreichen Stand pro Quelle.

## Feature-Ideen in sinnvoller Reihenfolge

1. **Neu in deinen Reihen:** gemeinsamer Einstieg für neu erschienen, bald verfügbar und neu entdeckte Reihen. Direkte Aktionen „Vormerken“, „Hinzufügen“, „Beim Anbieter öffnen“.
2. **Release-Erinnerungen je Reihe:** gezielte freiwillige Erinnerungen und Hinweise bei Terminverschiebung, gestützt auf verlässliche Veröffentlichungsdaten.
3. **Reihen entdecken und abonnieren:** Vorschau vor Aktivierung, Inhalts-Sprachauswahl, erste Folgen direkt auswählen. Reihen ohne eigene Bibliotheksfolge werden trotzdem berücksichtigt.
4. **Persönliche Hörwarteschlange:** vorhandenes „Später hören“ um manuelle Reihenfolge und „Als Nächstes einreihen“ erweitern; keine zweite konkurrierende Merkliste schaffen.
5. **Katalogfehler melden / Reihe wünschen:** vorbereitetes Formular mit Reihe/Folge und Fehlerart. Erst nach Nutzeraktion senden; hilfreich für langfristige Datenpflege.

Vorhandene Favoriten, Stimmungslisten, Zufallsauswahl, Statistiken und Merkliste sind bereits eine breite Funktionsbasis. Zunächst die Verbindung zwischen Entdecken, Vormerken und Hören schließen.

## Quellen

- https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/manifest.json
- https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/upcoming_releases.json
- https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators.json
- https://github.com/Digi951/hoerspiel-kataloge/blob/main/scripts/check_catalogs.py

Live-Abrufkopien des Manifests und Terminfeeds sowie der akzeptierte Screenshot liegen neben diesem Bericht. Testlog und Build-Artefakte: `/tmp/episode-audit-20260908/`.
