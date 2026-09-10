# Katalog-Datenvertrag

**Gilt zwischen:** App `EpisodeTracker` (HörspielLog) ⇄ Katalog-Repo `Digi951/hoerspiel-kataloge`
**Eingeführt mit:** V1.18, Paket 1 (Datenvertrag)
**Stand:** 2026-09-10
**Verwandte Dokumente:** `docs/2026-09-08-v1.18-release-plan.md` §5 · `docs/plans/v1.18-paket-1-spec.md` · `docs/plans/v1.18-paket-1-generatorweg.md`

---

## 1. Zweck und Geltungsbereich

Dieses Dokument beschreibt verbindlich, welche Dateien das Katalog-Repo bereitstellt
und welche Felder die App daraus liest. Es deckt **zwei Formate** ab:

- **Legacy** — das bis einschließlich V1.17 ausgelieferte Format (flache
  `spotifyURL`-Felder, kein Status, keine Provenienz).
- **V2** — das mit V1.18 eingeführte, **additiv** erweiterte Format
  (`links`-Objekt inkl. generischer Quelle, `releaseStatus`, `releaseDate`,
  `sourceCheckedAt`, `changedAt`).

**Grundregeln:**

1. **Additiv, sprachunabhängig.** V2 fügt nur optionale Felder hinzu. Kein
   Pflichtfeld wird entfernt, kein Feld ändert Typ oder Bedeutung.
2. **Beide Formate bleiben unbegrenzt gültig.** Die App erkennt das Format pro
   Datei automatisch (Feld-Anwesenheit), nicht über einen Schalter. Es gibt
   keinen Stichtag für eine Migration.
3. **Toleranz beim Lesen, Strenge bei Typfehlern.** Unbekannte Felder und
   unbekannte Enum-Rohwerte werden ignoriert bzw. auf einen sicheren Default
   abgebildet. Ein vorhandenes Feld mit **falschem Typ** (z. B. Zahl statt
   `yyyy-MM-dd`-String) lässt den Decode scheitern — der betroffene Payload wird
   verworfen, statt still ein Feld zu verschlucken.
4. **Identität ist nie Anzeige.** Titel, Datum und Anzeigename sind niemals
   Identität. Siehe §6.

Kalendertage sind überall `yyyy-MM-dd` (ISO-8601-Datum ohne Zeit), interpretiert
als **lokale Mitternacht** (`Calendar(identifier: .gregorian)`,
`Locale(identifier: "en_US_POSIX")`, `timeZone = .current`). Nicht UTC — sonst
zeigt eine Zeitzone westlich von UTC den Vortag.

---

## 2. Dateien im Katalog-Repo

| Datei | Inhalt |
|---|---|
| `manifest.json` | Liste aller Kataloge (§3). |
| `catalogs/<lang>/<slug>.json` | Ein Katalog: Metadaten + Einträge (§4). `<lang>` ist ISO-639-1 (`de`, `en`, `fr`). |
| `upcoming_releases.json` | Terminfeed: angekündigte Folgen mit Datum (§5). Wird bei jedem Generator-Lauf vollständig ersetzt. |

Alle drei werden über GitHub-raw-URLs abgerufen und mit ETag / `Last-Modified`
zwischengespeichert.

---

## 3. Manifest (`manifest.json`)

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-09-10",
  "catalogs": [
    {
      "id": "die-drei-fragezeichen",
      "name": "Die drei ???",
      "language": "de",
      "style": "numbered",
      "url": "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators.json"
    }
  ]
}
```

| Feld | Typ | Pflicht | Bedeutung / Regel |
|---|---|---|---|
| `schemaVersion` | Int | **ja** | Aktuell `1`. Im V1.17-Decoder **nicht-optional** — darf nie entfernt werden. Nur bei einer **nicht-additiven** Manifest-Änderung erhöhen. |
| `updatedAt` | String (`yyyy-MM-dd`) | nein | Redaktioneller Stand des Manifests. |
| `catalogs[]` | Array | **ja** | Alle bekannten Kataloge, sprachübergreifend. Die App filtert nach Gerätesprache. |
| `catalogs[].id` | String (kebab-case) | **ja** | Stabile, eindeutige Kennung. Ändert sich **nie**, auch nicht bei Umbenennung des Anzeigenamens. |
| `catalogs[].name` | String | **ja** | Anzeigename. **Stabil für Legacy-Clients** — V1.17 matcht namensbasiert. |
| `catalogs[].language` | String (ISO-639-1) | nein | Default `"de"`. Bestimmt, ob der Katalog auf dem Gerät sichtbar ist. |
| `catalogs[].style` | String | nein | `numbered` (Default) \| `anthology`. Unbekannter Wert ⇒ `numbered`. Steuert `usesEpisodeNumbers` in der App. |
| `catalogs[].url` | String (URL) | **ja** | GitHub-raw-URL der Katalogdatei. `blob`-URLs werden clientseitig normalisiert. |

Die Manifest-Struktur ändert sich mit V1.18 **nicht**. `style` ist bereits seit
V1.16 optional vorgesehen; V1.18 füllt es erstmals mit `anthology`.

---

## 4. Katalogdatei (`catalogs/<lang>/<slug>.json`)

Wrapper-Dokument mit Metadaten und `entries[]`. Ein reines Flach-Array
(`[ {…}, {…} ]`) wird als **Legacy-Eingang** weiterhin akzeptiert, aber nicht
mehr empfohlen.

### 4.1 Dokument-Ebene

| Feld | Typ | Pflicht | Legacy | V2 | Bedeutung / Regel |
|---|---|---|:---:|:---:|---|
| `collectionName` | String | empfohlen | ✓ | ✓ | Sammlungsname. Fehlt er, fällt die App auf den Manifest-`name` zurück. |
| `version` | Int | empfohlen | ✓ | ✓ | Grobe Katalog-Revision. **Monoton steigend** bei jeder redaktionellen Änderung. Basis für `CatalogSnapshot.version` und Delta-Erkennung (Paket 4). |
| `lastUpdated` | String (`yyyy-MM-dd`) | empfohlen | ✓ | ✓ | Redaktioneller Stand. |
| `entryCount` | Int | nein | ✓ | ✓ | Nur Konsistenz-Hinweis. Die App verlässt sich auf `entries.count`. |
| `catalogFormat` | Int | nein | – | ✓ | `1` = Legacy, `2` = V2. Fehlt ⇒ `1`. **Reiner Intent-Marker** für Generator und Validator; der App-Decoder wertet ihn nicht aus (er erkennt das Format an den Feldern). |
| `entries[]` | Array | **ja** | ✓ | ✓ | Siehe §4.2. |

### 4.2 Eintrag (`entries[]`)

| Feld | Typ | Pflicht | Legacy | V2 | Bedeutung / Regel |
|---|---|---|:---:|:---:|---|
| `number` | Int | bei `kind: regular` in `numbered`-Katalogen | ✓ | ✓ | Laufende Folgennummer. Bei `style: anthology` **weglassen**. |
| `kind` | String | nein (Default `regular`) | ✓ | ✓ | `regular` \| `special`. In `anthology`-Katalogen **muss** jeder Eintrag `special` sein — die Invariante wird beim Import erzwungen (Paket 2b). |
| `slug` | String (kebab-case) | bei `kind: special` **ja**; in `anthology` **ja** | ✓ | ✓ | Stabile Identität ohne Nummer. Eindeutig im Katalog. Wird bei Titelkorrekturen **nicht** neu berechnet. |
| `title` | String | **ja** | ✓ | ✓ | Anzeigetitel. |
| `releaseYear` | Int | nein (Default `0`) | ✓ | ✓ | `0` bedeutet „unbekannt" und wird nie geraten. |
| `collectionName` | String | nein | ✓ | ✓ | Überschreibt den Dokument-Wert für diesen Eintrag (Sammel-Kataloge). |
| `links` | Object `{string: string}` | nein | – | ✓ | Streaming- und Quell-Links. Keys siehe §4.3. Leere / reine Whitespace-Werte werden beim Einlesen entfernt. |
| `spotifyURL` `appleMusicURL` `deezerURL` `audibleURL` | String (URL) | nein | ✓ | – *(deprecated)* | Legacy-Flachfelder. Werden weiterhin **gelesen** und nach `links` gemappt (`spotify`/`apple`/`deezer`/`audible`). Ein expliziter `links`-Eintrag gewinnt gegen das gleichnamige Flachfeld. In V2 **nicht mehr schreiben**. |
| `releaseDate` | String (`yyyy-MM-dd`) | nein | – | ✓ | Kalendertag der Veröffentlichung. Nur setzen, wenn belastbar bekannt. Erlaubt einer Anthologie-Folge, ihr Datum selbst zu tragen (der nummern-gekeyte Feed braucht sie dann nicht). |
| `releaseStatus` | String | nein (Default `unknown`) | – | ✓ | `announced` \| `released` \| `unknown`. Siehe Statusregeln §4.4. |
| `sourceCheckedAt` | String (`yyyy-MM-dd`) | nein | – | ✓ | Datum, an dem `links.source` zuletzt redaktionell geprüft wurde. |
| `changedAt` | String (`yyyy-MM-dd`) | nein | – | ✓ | Datum der letzten **inhaltlichen** Änderung dieses Eintrags. Basis für Neuigkeiten-Deltas (Paket 4). |

Ein vorhandenes `releaseDate` / `sourceCheckedAt` / `changedAt` mit einem Wert,
der **kein** `yyyy-MM-dd` ist (falscher Typ oder unparsebarer String), lässt den
Decode des gesamten Dokuments scheitern (Fail-Fast). `releaseStatus` dagegen ist
tolerant: ein unbekannter Rohwert wird zu `unknown`, ohne Fehler.

### 4.3 `links`-Keys

| Key | Zweck |
|---|---|
| `spotify` `apple` `deezer` `audible` `audioteka` `storytel` | Streaming-Dienste. Entspricht `StreamingService.rawValue`. Werden als Dienst-Zeilen in der Detailansicht gerendert. |
| `source` | **Reservierter Key** für eine generische Originalquelle (Sender-Mediathek, Studio-Seite, France-Culture-Seite …). `StreamingService(rawValue: "source")` ist bewusst `nil` — die Quelle erscheint nie als Dienst-Zeile, sondern nur als „Originalquelle öffnen"-Fallback (Paket 2b). |
| *(weitere)* | `links` ist bewusst offen. Unbekannte Keys bleiben beim Einlesen erhalten, werden aber von keiner Dienst- oder Quell-Logik aufgegriffen. |

> **Hinweis zum Release-Plan.** §5 des Release-Plans nennt das Feld `sourceURL`.
> Umgesetzt wird es als `links.source` (URL-Heim) plus dem Skalarfeld
> `sourceCheckedAt` (Prüfdatum). Kein separates `sourceURL`-Feld — `links["source"]`
> und die computed `CatalogEntry.sourceURL` sind seit Paket 2b ausgeliefert.

### 4.4 Statusregeln (normativ)

1. Fehlt `releaseStatus`, gilt **`unknown`**. `unknown`-Einträge sind vollwertig
   (Bibliothek, Statistik, Autocomplete) — sie gelten nur nicht als „erschienen".
2. `releaseStatus: announced` **+** `releaseDate` in der Zukunft ⇒ Terminkandidat
   für die Feed-Projektion (§5).
3. `releaseStatus: announced` **+** `releaseDate` in der Vergangenheit bleibt
   `announced` — **nicht** automatisch `released`. Die UI (Paket 4) zeigt
   „unbestätigt". Der Generator darf den Eintrag bei belegter Veröffentlichung
   auf `released` heben.
4. `releaseDate` **ohne** `releaseStatus` ⇒ Status bleibt `unknown`; das Datum
   ist rein informativ.
5. **`unknown` wird nie zu `released` umgedeutet.**
6. **Terminverschiebung:** `releaseDate` ändern **und** `changedAt` auf das
   Änderungsdatum setzen. Es gibt in V1.18 keinen `delayed`- oder
   `cancelled`-Status.

---

## 5. Terminfeed (`upcoming_releases.json`)

```json
{
  "feedVersion": 1,
  "updatedAt": "2026-09-10",
  "releases": [
    { "catalogID": "die-drei-fragezeichen", "number": 241, "title": "Meister des Lichts", "releaseDate": "2026-09-18", "releaseStatus": "announced" },
    { "catalogID": "fr-anthologie-pilot", "slug": "le-secret-de-la-tour", "title": "Le secret de la tour", "releaseDate": "2026-09-25" }
  ]
}
```

| Feld | Typ | Pflicht | Bedeutung / Regel |
|---|---|---|---|
| `feedVersion` | Int | nein (Default `1`) | Fluchtweg-Marker. `1` = additiv erweiterter Feed. Ein künftiger **echter** Bruch (nicht nur eine von V1.17 verworfene Zeile) führt `2` **und** eine separate Datei ein; der V1-Feed wird dann weiter erzeugt. Aktuell nur gelesen, nicht ausgewertet. |
| `updatedAt` | String (`yyyy-MM-dd`) | nein | Datum des Generator-Laufs. |
| `releases[]` | Array | **ja** | Wird bei **jedem** Lauf vollständig ersetzt. Kann Duplikate enthalten (verschobene Folge) — die App dedupliziert nach `id` und behält den früheren Termin. |
| `releases[].catalogID` | String | **ja** | = `manifest.catalogs[].id`. |
| `releases[].number` | Int | bei `numbered`-Serien **ja**; bei `anthology` **weglassen** | War bis V1.17 Pflicht, ist jetzt optional. |
| `releases[].slug` | String | bei `anthology` **ja** | Identität ohne Nummer. |
| `releases[].title` | String | **ja** | Anzeigetitel. |
| `releases[].releaseDate` | String (`yyyy-MM-dd`) | **ja** | Angekündigter Termin. Ein fehlendes oder falsch getyptes Datum lässt genau diese Zeile wegfallen (§7). |
| `releases[].releaseStatus` | String | nein (Default `announced`) | Im Feed praktisch immer `announced`. `released`, sobald belegt — dann fällt die Zeile beim nächsten Lauf ohnehin raus. Unbekannter Rohwert ⇒ `unknown` (tolerant). |

**Identität einer Terminzeile:** `catalogID` + (`number` ?? `slug`). Eine Zeile
**ohne** `number` **und ohne** `slug` hat keine stabile Identität und wird
verworfen.

Der Feed ist eine **erzeugte Projektion** aus den redaktionellen Katalogdaten
(bzw. der play-europa-Vorschau), keine eigene Wahrheitsquelle.

---

## 6. ID-Referenz

| Ebene | Stabile Identität | Anzeige- / Legacy-Identität |
|---|---|---|
| Katalog | `manifest.catalogs[].id` | `name` |
| Eintrag `numbered` / `regular` | `number` (im Katalog) | `number` |
| Eintrag `special` / jede `anthology`-Folge | `slug` (im Katalog) | `title` |
| Terminzeile | `catalogID` + (`number` ?? `slug`) | `title` |

- Slugs werden bei Titelkorrekturen **nicht** neu berechnet.
- Zwei Kataloge müssen paarweise eindeutige `id` **und** `name` haben (die App
  dedupliziert beim Manifest-Laden über beides).
- SwiftData- und Cloud-Sync-Schlüssel werden in V1.18 **nicht** neu berechnet.

---

## 7. Kompatibilitätszusagen

### 7.1 V1.17 liest V2-Kataloge

Der V1.17-`CatalogEntry`-Decoder kennt nur `number` / `kind` / `slug` / `title` /
`releaseYear` / `collectionName` / `links` sowie die vier Legacy-Flachfelder.
Alle V2-Zusatzfelder (`releaseDate`, `releaseStatus`, `sourceCheckedAt`,
`changedAt`, `catalogFormat`) hat sein `CodingKeys`-Enum nicht — sie werden vom
synthetisierten Decoder **ignoriert**. Ein V2-Katalog dekodiert unter V1.17 ohne
Fehler; bekannte Felder kommen unverändert an. (Testdouble: `LegacyCatalogEntry17`
in `EpisodeTrackerTests/CatalogDataContractTests.swift`.)

### 7.2 V1.17 liest den erweiterten Terminfeed

`UpcomingReleasesDocument` kapselt in V1.17 jede Zeile in `LenientRelease` →
`try? UpcomingRelease(from:)`. In V1.17 ist `UpcomingRelease.number`
**nicht-optional**:

- Eine Zeile **mit** `number` dekodiert normal — Zusatzfelder (`slug`,
  `releaseStatus`, `feedVersion`) werden ignoriert.
- Eine Zeile **ohne** `number` (Anthologie) lässt
  `try container.decode(Int.self, forKey: .number)` werfen; `LenientRelease`
  verwirft **nur diese Zeile**. Der V1.17-Client zeigt sie nicht an, stürzt aber
  nicht ab, und der Rest des Feeds bleibt intakt.

V1.17-Clients haben ohnehin **null** Anthologie-Kataloge (das Manifest ist
sprachgefiltert; Anthologie-Kataloge erscheinen erst mit V1.18/Paket 5), sehen
also faktisch keine Anthologie-Terminzeilen.

### 7.3 V1.18 liest Legacy-Kataloge unverändert

Der V1.18-Decoder liest einen Legacy-Eintrag Bit für Bit wie bisher: Flach-URLs
landen in `links`, die neuen Felder sind `nil` bzw. `.unknown`. Ein Legacy-Eintrag
wird **ohne** die neuen Keys zurückgeschrieben (`encode` schreibt `releaseDate` /
`sourceCheckedAt` / `changedAt` nur wenn belegt, `releaseStatus` nur wenn
`!= .unknown`) — der Disk-Cache für Bestandsdaten ändert sich beim nächsten
Schreiben nicht.

---

## 8. Beispiel-JSON

### 8.1 Legacy-Katalog

```json
{
  "collectionName": "Die drei ???",
  "version": 6,
  "lastUpdated": "2026-06-14",
  "entryCount": 2,
  "entries": [
    {
      "number": 1,
      "title": "und der Super-Papagei",
      "releaseYear": 1979,
      "spotifyURL": "https://open.spotify.com/album/4N9tvSjWfZXx3eHKblYEWQ",
      "appleMusicURL": "https://music.apple.com/de/album/folge-1/1092529875",
      "deezerURL": "https://www.deezer.com/album/12761822",
      "audibleURL": "https://www.audible.de/pd/B0B1QKF361"
    },
    {
      "kind": "special",
      "slug": "live-und-der-superpapagei-2019",
      "title": "Live: und der Super-Papagei (2019)",
      "releaseYear": 2019,
      "spotifyURL": "https://open.spotify.com/album/xxxx"
    }
  ]
}
```

### 8.2 V2-Katalog (`numbered`)

```json
{
  "collectionName": "Die drei ???",
  "version": 7,
  "lastUpdated": "2026-09-10",
  "entryCount": 2,
  "catalogFormat": 2,
  "entries": [
    {
      "number": 240,
      "title": "und der schwarze Skorpion",
      "releaseYear": 2026,
      "links": {
        "spotify": "https://open.spotify.com/album/aaa",
        "apple": "https://music.apple.com/de/album/aaa",
        "source": "https://www.dreifragezeichen.de/folgen/240"
      },
      "releaseDate": "2026-08-01",
      "releaseStatus": "released",
      "sourceCheckedAt": "2026-09-01",
      "changedAt": "2026-08-15"
    },
    {
      "number": 241,
      "title": "Meister des Lichts",
      "releaseYear": 2026,
      "links": { "source": "https://www.dreifragezeichen.de/folgen/241" },
      "releaseDate": "2026-09-18",
      "releaseStatus": "announced",
      "changedAt": "2026-09-09"
    }
  ]
}
```

### 8.3 V2-Katalog (`anthology`)

```json
{
  "collectionName": "France Culture — Fictions",
  "version": 1,
  "lastUpdated": "2026-09-10",
  "entryCount": 2,
  "catalogFormat": 2,
  "entries": [
    {
      "kind": "special",
      "slug": "la-premiere-enquete",
      "title": "La première enquête",
      "releaseYear": 2024,
      "links": {
        "source": "https://www.radiofrance.fr/franceculture/podcasts/fiction/la-premiere-enquete",
        "spotify": "https://open.spotify.com/episode/bbb"
      },
      "releaseDate": "2024-03-11",
      "releaseStatus": "released",
      "sourceCheckedAt": "2026-09-05",
      "changedAt": "2026-09-05"
    },
    {
      "kind": "special",
      "slug": "le-secret-de-la-tour",
      "title": "Le secret de la tour",
      "releaseYear": 2026,
      "links": { "source": "https://www.radiofrance.fr/franceculture/podcasts/fiction/le-secret-de-la-tour" },
      "releaseDate": "2026-09-25",
      "releaseStatus": "announced",
      "changedAt": "2026-09-08"
    }
  ]
}
```

### 8.4 Terminfeed

```json
{
  "feedVersion": 1,
  "updatedAt": "2026-09-10",
  "releases": [
    { "catalogID": "die-drei-fragezeichen", "number": 241, "title": "Meister des Lichts", "releaseDate": "2026-09-18", "releaseStatus": "announced" },
    { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "2026-09-11" },
    { "catalogID": "fr-anthologie-pilot", "slug": "le-secret-de-la-tour", "title": "Le secret de la tour", "releaseDate": "2026-09-25" }
  ]
}
```

---

## 9. Änderungshistorie

| Datum | Version | Änderung |
|---|---|---|
| 2026-09-10 | 1.0 | Erstfassung mit V1.18/Paket 1: V2-Format (`links` inkl. `source`, `releaseStatus`, `releaseDate`, `sourceCheckedAt`, `changedAt`, `catalogFormat`), Terminfeed additiv (`number` optional, `slug`, `releaseStatus`, `feedVersion`), Statusregeln, ID-Referenz, V1.17-Kompatibilitätszusagen. |
