# P6-C — Simulator-gestützte Sichtprüfung

Stand: 2026-09-11. Begleitet [`v1.18-paket-6-plan.md`](../../plans/v1.18-paket-6-plan.md).
Durchgeführt mit `mcp__Claude_Code_iOS_Simulator__control` (Tap/Swipe) plus
`xcrun simctl io screenshot` für die eigentlichen Bildaufnahmen — der
Screenshot/Inspect-Kanal des Steuerungstools war während dieser Sitzung
gestört (siehe "Werkzeug-Einschränkungen" unten). App-Sprache wurde per
`xcrun simctl launch ... -AppleLanguages "(xx)" -AppleLocale xx_XX`
umgeschaltet (kein persistenter Simulator-Zustand, kein `defaults`-Workaround
nötig).

## Geprüfte Bildschirme

| Bildschirm | DE | EN | FR | iPad |
|---|---|---|---|---|
| Bibliothek leer (P6-A-Fix) | ✅ (P6-A-Commit) | ✅ | ✅ | ✅ (eigenes Split-Layout, siehe unten) |
| Kataloge (P6-B-Wording) | ✅ (P6-B-Commit) | ✅ | ✅ | — |
| Einstellungen → Darstellung | ✅ | ✅ (Fund, siehe unten) | ✅ (Fund, siehe unten) | ✅ |
| Neuigkeiten | — | ✅ (leer, korrekt lokalisiert) | — | — |
| Sprachfilter mit 2 Sprachen (Paket-3-Altfund) | — | — | ✅ | — |

Screenshots liegen in diesem Verzeichnis, benannt
`<sprache>-<gerät>-<bildschirm>[-fix].png`.

## Bestätigt: P6-A und P6-B funktionieren sprachunabhängig

- **P6-A (Erststart-Layout):** [en-iphone-bibliothek-leer-scroll.png](en-iphone-bibliothek-leer-scroll.png),
  [fr-iphone-bibliothek-leer-scroll.png](fr-iphone-bibliothek-leer-scroll.png) —
  genau eine primäre Aktion, Fußtext vollständig über der Tab-Bar, in EN und
  FR identisch zum bereits im P6-A-Commit verifizierten DE-Verhalten.
- **P6-B (Aktivieren/Deaktivieren):** der Hint ist reiner VoiceOver-Text ohne
  sichtbare UI-Änderung — visuell in [fr-iphone-kataloge.png](fr-iphone-kataloge.png)
  bestätigt unverändert; ein Accessibility-Baum-Beleg bleibt am gestörten
  Inspect-Kanal hängen (siehe unten, deckungsgleich mit dem in P6-B bereits
  dokumentierten offenen Faden).
- **Paket-3-Altfund "Sprachfilter nie mit 2 Sprachen optisch geprüft"** —
  jetzt nachgeholt: [fr-iphone-kataloge.png](fr-iphone-kataloge.png) zeigt den
  Sprachfilter (Allemand/Anglais) korrekt mit zwei Einträgen.

## Fund 1 — behoben in diesem Commit: Darstellung-Umschalter unübersetzt

`AppearanceMode.title` (`ContentView.swift`) gab hartkodiertes Deutsch
zurück ("System"/"Hell"/"Dunkel") ohne xcstrings-Eintrag. Sichtbar in
[fr-iphone-reglages.png](fr-iphone-reglages.png) (vor dem Fix: "System /
Hell / Dunkel" mitten im sonst vollständig französischen Bildschirm).

**Bewertung:** trivial und risikofrei (reine Textextraktion einer
3-Fall-`switch`, keine Logikänderung) — im selben Commit behoben, siehe
`ContentView.swift` und `Localizable.xcstrings`
(`Appearance.Mode.System/.Light/.Dark`), neue Tests in
`AppearanceModeTests.swift`. Nachweis nach Fix:
[fr-iphone-reglages-fix.png](fr-iphone-reglages-fix.png) ("Système / Clair
/ Sombre"), [en-iphone-einstellungen-darstellung.png](en-iphone-einstellungen-darstellung.png)
("System / Light / Dark").

## Fund 2 — nicht behoben, als Folge-Faden vermerkt: Katalog-Detailtexte unübersetzt

Auf dem Kataloge-Detailbildschirm (`CatalogManagementView.swift`) sind zwei
Texte hartkodiertes Deutsch, weil sie über `String`-Interpolation in
`static func`s gebaut und erst danach in `Text(...)` verpackt werden — dieser
Umweg entgeht Xcodes automatischer String-Extraktion (anders als die
direkten `Text("…")`-Literale, die im selben Screen bereits korrekt
übersetzt sind):

- `CatalogToggleRow.activeCountLabel(active:total:)` → `"\(active) von
  \(total) aktiv"` — sichtbar in [fr-iphone-kataloge.png](fr-iphone-kataloge.png)
  als "0 von 5 aktiv" mitten in einem sonst französischen Bildschirm.
- `CatalogToggleRow.catalogSubtitle(episodeCount:titleCount:)` → "Nicht
  geladen" / "X Titel" / "X Folge(n) · X Titel" — derselbe Mechanismus,
  in den Screenshots durch die (im Test-Setup) leere Bibliothek nicht mit
  Zahlen belegt, aber im Code identisch betroffen.

Bemerkenswert: die **eine Ebene höher liegende** Zusammenfassung in
`SettingsView.swift` ("X von X Katalogen aktiv") ist bereits korrekt über
`String(localized:defaultValue:)` lokalisiert — der Bug sitzt nur in der
tieferen Detailansicht.

**Bewertung: nicht trivial**, absichtlich nicht in diesem Commit
mitgezogen:
- Beide Funktionen sind über drei Sprachen hinweg pluralformabhängig
  ("1 Folge" vs. "8 Folgen" / "1 titre" vs. "2 titres" usw.) — echte
  Pluralregeln brauchen `stringsdict`/Plural-Varianten in `Localizable.xcstrings`, nicht nur einen einfachen `String(localized:)`-Aufruf.
- `CatalogManagementViewTests.swift` hat vier bestehende Tests, die exakte
  deutsche String-Werte assertieren (`testSubtitle...`,
  `testActiveCountLabel...`) — eine echte Lokalisierung ändert deren
  Vertrag und muss die Tests mit-migrieren, nicht nebenbei.
- Root-Cause-gerecht lösen heißt hier: eine wiederverwendbare
  Pluralisierungs-Konvention für den ganzen Katalogbereich festlegen,
  nicht zwei Funktionen isoliert flicken.

→ als Hintergrund-Task vorgemerkt (siehe Session-Notiz), Aufnahme in die
"Offenen Fäden" von P6-E.

## Fund 3 — nicht behoben, nur dokumentiert: App-Icon-Beschreibungen unübersetzt

[en-iphone-app-icon.png](en-iphone-app-icon.png): die vier Alternate-Icon-
Untertitel ("Audiowelle", "Blaues Originalsymbol", "Retro mit
Hörspielgefühl", "Direkt als Audio-App lesbar") bleiben in EN unübersetzt.
Niedrige Priorität (rein dekorativer Auswahlbildschirm, kein Kernablauf) —
außerhalb des von Spec §2/§5 benannten Scopes dieses Pakets, hier nur als
Fund vermerkt statt stillschweigend mitgezogen oder in P6-C behoben.

## Werkzeug-Einschränkungen dieser Sitzung

- `mcp__Claude_Code_iOS_Simulator__control`s `screenshot`- und
  `inspect`-Aktionen lieferten durchgehend `captureFailed` bzw. "inspect
  nicht verfügbar", unabhängig von Neustarts des Simulators. Workaround:
  `xcrun simctl io <udid> screenshot <pfad>` für alle Bildbelege in diesem
  Verzeichnis; `tap`/`swipe` des Steuerungstools funktionierten normal.
  Ein echter Accessibility-Baum-Beleg (für P6-B, D3) bleibt damit offen.
- Bei zwei gleichzeitig gebooteten Simulatoren (iPhone + iPad) routete
  `tap` ohne explizites `device`-Argument fälschlich zum iPhone — Fix: bei
  Mehrgeräte-Sitzungen `device` auf jedem `tap`-Aufruf mitgeben, nicht nur
  auf `attach`.

## Nicht Teil dieser Prüfung (bewusst)

- Echtes VoiceOver-Hören (Sprachausgabe, Navigationsreihenfolge) — braucht
  ein physisches Gerät, bleibt offener Faden wie in Paket 3/4/5 dokumentiert.
- Muttersprachliche FR-Gegenprüfung.
- Große-Schrift-Test (Dynamic Type) — aus Zeitgründen in dieser Runde nicht
  durchgeführt; als weiterer offener Punkt für eine künftige Sichtprüfung
  vermerkt statt stillschweigend als erledigt geführt.
- iPad nur mit Bibliothek + Einstellungen geprüft (Abnahmekriterium 5
  verlangt genau dieses Minimum) — keine weiteren iPad-Bildschirme.
