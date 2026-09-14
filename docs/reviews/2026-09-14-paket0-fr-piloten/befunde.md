# P0-B — Simulator-Verifikation mit echten FR-Daten

Stand: 2026-09-14. Begleitet [`v1.18-paket-0-plan.md`](../../plans/v1.18-paket-0-plan.md).

Voraussetzung: der P0-A-Commit im `hoerspiel-kataloge`-Repo wurde nach
GitHub gepusht, damit `raw.githubusercontent.com` das aktualisierte
Manifest ausliefert — ohne Push hätte der Simulator nur den alten Stand
gesehen (lokale Commits sind für die App unsichtbar).

## Ablauf

Frisch installierte App auf dem iPhone-17-Pro-Simulator, Sprache per
`xcrun simctl launch -AppleLanguages '(fr)' -AppleLocale fr_FR` auf
Französisch gestellt (kein persistenter `defaults`-Workaround nötig,
siehe [[skill_simulator_defaults]]).

## Bestätigt: echte FR-Kataloge kommen über die reguläre Pipeline an

[fr-iphone-erststart-neue-kataloge-banner.png](fr-iphone-erststart-neue-kataloge-banner.png) —
bereits beim allerersten Start zeigt die Bibliothek die Meldung
"2 nouveaux catalogues aj[outés] … Astérix — la BD audio et d'autres
catalogues ont été ajoutés à ta bibliothèque." Das bestätigt den in Spec
§1 erwarteten Weg: **kein Code in `EpisodeTracker` musste geändert
werden** — die App hat die zwei neuen Kataloge automatisch über den
bestehenden Manifest-Mechanismus (`CatalogSourceRegistry`) erkannt,
sobald sie auf GitHub lagen.

[fr-iphone-catalogues-echte-daten.png](fr-iphone-catalogues-echte-daten.png) —
Einstellungen → Catalogues zeigt exakt die kuratierten Daten:
"Astérix — la BD audio, 8 Titel" und "Mila et Jaba, 10 Titel", beide
aktiviert ("2 von 2 aktiv"). Die Zahlen (8 bzw. 10) stimmen mit den in
P0-A recherchierten und verifizierten Einträgen überein.

[fr-iphone-reglages.png](fr-iphone-reglages.png) — die
Einstellungen-Übersicht bleibt vollständig französisch, inklusive der in
P6-C behobenen "Système/Clair/Sombre"-Übersetzung (`AppearanceMode.title`)
— keine Regression durch die neuen Kataloge.

[fr-iphone-statistiques.png](fr-iphone-statistiques.png),
[fr-iphone-a-suivre.png](fr-iphone-a-suivre.png) — Statistik- und
Smart-Listen-Bildschirm (Paket 3) rendern korrekt auf Französisch mit den
aktivierten FR-Katalogen im Hintergrund (leerer Zustand, da noch keine
Folge angelegt wurde — siehe unten).

## Bekannter, bereits dokumentierter Fund erneut sichtbar (nicht neu)

Auf dem Catalogues-Bildschirm steht "8 **Titel**" / "10 **Titel**" — das
deutsche Wort mitten im französischen Bildschirm. Das ist exakt der in
[P6-C, Fund 2](../2026-09-11-paket6-sichtpruefung/befunde.md) bereits
gefundene, bewusst nicht behobene `CatalogToggleRow`-Lokalisierungsbug
(hartkodiertes Deutsch durch String-Interpolation statt `Text("…")`) —
hier nur mit echten statt synthetischen Daten reproduziert. Kein neuer
Fund, keine erneute Aufnahme nötig; bleibt beim vorgemerkten
Hintergrund-Task `task_69b9d4a0`.

## Nicht abschließend geklärt: Titel-Autovervollständigung mit echten Titeln

Versucht: manuell eine neue Folge anlegen und über das Titelfeld
("Saisir le numéro de l'épisode … Les titres correspondants apparaissent
en suggestion") gegen die aktiven Kataloge matchen lassen. Eingaben wie
"Asterix Gaulois" oder "Gaulois" (das Simulator-Steuerungstool kann keine
akzentuierten Zeichen wie "é" tippen — bestätigtes Werkzeug-Limit dieser
Sitzung, kein App-Fund) lösten keine Vorschläge aus.

**Nicht als Befund gewertet**, weil nicht sauber von einem echten Bug
unterschieden werden konnte: das Umschalten des "Épisode spécial"-Toggles
(relevant, weil unsere Katalogeinträge `kind: special` sind) ließ sich in
dieser Sitzung nicht zuverlässig per Tap auslösen — siehe
"Werkzeug-Einschränkungen" unten. Ob die Autovervollständigung für
Anthologie-/Spezial-Einträge tatsächlich funktioniert, bleibt offen und
sollte in einer künftigen Sitzung mit funktionierendem Toggle-Tap (oder
per gezieltem XCTest gegen `CatalogTitleAutocomplete` mit einem
`kind: special`-Fixture) nachgeholt werden — dies ist **keine
Abnahmevoraussetzung von P0** (Spec §5 verlangt Aktivierung, Bibliothek,
Statistik, Widget, Smart-Lists, nicht explizit die manuelle
Folgenerfassung per Autovervollständigung), wird hier aber transparent als
offener Punkt vermerkt statt stillschweigend als erledigt geführt.

## Werkzeug-Einschränkungen dieser Sitzung

- `mcp__Claude_Code_iOS_Simulator__control`s `screenshot`- und
  `inspect`-Aktionen sind weiterhin gestört (wie schon in P6-C) —
  `xcrun simctl io screenshot` wurde durchgehend als Ersatz genutzt.
- **Neu in dieser Sitzung:** `tap` war ungewöhnlich unzuverlässig, wenn
  die Zielkoordinate aus der herunterskalierten Bildvorschau des Read-
  Tools abgeschätzt wurde (920×2000-Anzeige eines 1206×2622-Screenshots)
  — mehrere Taps auf augenscheinlich korrekte Positionen (Tab-Leiste,
  große Buttons) blieben wirkungslos. Zuverlässig wurde es erst, nachdem
  Ziel-Koordinaten aus dem **nativen** Screenshot-Pixel-Raster (per
  Pillow-Crop exakt vermessen, nicht aus der Vorschau abgelesen) berechnet
  wurden. Für künftige Sitzungen: Koordinaten immer aus einem präzisen
  Pixel-Crop des nativen Screenshots ableiten, nicht aus der
  Terminal-Bildvorschau abschätzen.
- `text` unterstützt nur druckbare ASCII-Zeichen — akzentuierte Zeichen
  (é, è, ê, œ …) werden stillschweigend verworfen. Für Sichtprüfungen mit
  französischem Text-Input (statt nur Anzeige) ist das eine relevante
  Einschränkung, hier dokumentiert statt unbemerkt zu bleiben.

## Nicht Teil dieser Prüfung

- Widget-Sichtprüfung mit den echten FR-Daten (Zeitaufwand in dieser
  Runde nicht mehr investiert, nachdem die Toggle-Interaktion sich als
  unzuverlässig erwies) — als offener Punkt vermerkt.
- iPad-Sichtprüfung — P0-Spec §5 verlangt sie nicht explizit (anders als
  P6-C); nicht durchgeführt.
- Echtes Anhören/Öffnen der "Originalquelle öffnen"-Links im Simulator
  (Safari-Deep-Link) — die URLs selbst wurden bereits in P0-A einzeln per
  `curl` gegen eine Live-200-Antwort verifiziert, das reicht als Beleg für
  die Datenrichtigkeit.
