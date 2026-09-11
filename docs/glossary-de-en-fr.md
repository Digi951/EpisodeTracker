# Glossar DE/EN/FR

Stand: 2026-09-11. Begleitet Paket 5 (`docs/plans/v1.18-paket-5-spec.md` D4).
Referenztabelle für die im Release-Plan (§3) genannten Kernbegriffe plus zwei
zusätzliche, ebenfalls bestätigte UI-Begriffe. Dient als Prüfliste während der
Übersetzung (P5-B) und als Grundlage für die künftige muttersprachliche
FR-Gegenprüfung (§6, noch unbesetzt).

## Kernbegriffe (§3)

| Begriff | DE | EN | FR | Belegt in `Localizable.xcstrings`? |
|---|---|---|---|---|
| Reihe / Katalog | Reihe (Nutzerfluss) / Katalog (Verwaltung) | Series / Catalog | Série / Catalogue | ✅ konsistent — "Reihe" kommt nur 1× im Nutzerfluss vor ("Wähle die Reihe, zu der deine Folge gehört." → "Choisis la série…"), "Katalog" durchgängig als "Catalogue" (61 Stellen) |
| Bibliothek | Bibliothek | Library | Bibliothèque | ✅ konsistent (9 Stellen) |
| angekündigt | angekündigt | announced | annoncé | ✅ konsistent (2 Stellen, beide im Kalender-/Termin-Kontext) |
| erschienen | erschienen | released | (nouvellement) sorti / nouveauté | ✅ nur 1 Stelle ("Neu erschienen" → "Nouveautés") — zu wenig Vorkommen für eine Musterprüfung, aber konsistent mit der Neuigkeiten-Bereichsbezeichnung |
| vormerken | vormerken / Merkliste / gemerkt | bookmark / Listen Later / Bookmarked | mettre de côté / écouter plus tard / mis de côté | ⚠️ **DE/EN selbst uneinheitlich** — siehe Abschnitt unten, FR spiegelt dieselbe Zweiteilung |
| gehört | gehört | listened | écouté | ✅ konsistent (27 Stellen) |

## "vormerken" — DE/EN sind selbst zweigeteilt, FR spiegelt das bewusst

Kein neuer FR-Fund, sondern eine bereits in DE/EN bestehende Zweiteilung, die
die FR-Übersetzung bewusst nachzeichnet statt künstlich zu vereinheitlichen:

| Kontext | DE | EN | FR |
|---|---|---|---|
| Bedienelement (Liste, Datumsachse) | „Auf Merkliste setzen" / „Von Merkliste entfernen" | "Add to Listen Later" / "Remove from Listen Later" | „Ajouter à écouter plus tard" / „Retirer d'écouter plus tard" |
| Smart-List-Name | „Später hören" | "Listen Later" | „Écouter plus tard" |
| Statistik-Kennzahl | „Gemerkt" | "Bookmarked" | „Mis de côté" |
| Formularfrage | „Was möchtest du dir merken?" | (kein direktes Äquivalent) | „Que veux-tu mettre de côté ?" |

Die Statistik-Kennzahl nutzt in allen drei Sprachen einen kürzeren,
eigenständigen Begriff (Gemerkt/Bookmarked/Mis de côté) statt der langen
Listenbezeichnung — das ist in DE/EN bereits so angelegt, FR übernimmt dieselbe
Struktur bewusst statt sie zu vereinheitlichen und dadurch von DE/EN abzuweichen.

## Zwei zusätzliche bestätigte Begriffe — Befund: nicht in der UI umgesetzt

§3 und §4.A bestätigen zwei Wortwahl-Entscheidungen, die beim Scan des
Codes **nicht** als tatsächliche UI-Strings gefunden wurden:

- **„Aktivieren"/„Deaktivieren" statt „Abonnieren"** — keine dieser vier
  Wörter kommt in `Localizable.xcstrings` vor. `CatalogManagementView.swift`
  verwendet einen unbeschrifteten `Toggle(isOn:)` ohne Verb-Text.
- **„Reihen auswählen" statt „Reihen entdecken"** — „Reihen auswählen"
  taucht nur als Code-Kommentar in `CatalogModels.swift:514` auf, nicht als
  `navigationTitle` oder Button-Text. Der tatsächliche Bildschirmtitel ist
  weiterhin **„Kataloge"**.

**Das ist kein Paket-5-Fund über FR, sondern eine vorbestehende Lücke
zwischen Release-Plan-Entscheidung und Code** — unabhängig von der
Sprachfrage. Für dieses Glossar heißt das: Es gibt aktuell nichts zu
übersetzen, weil die bestätigte deutsche Formulierung selbst noch nicht in
der UI angekommen ist. Kein Gate-Blocker für Paket 5 (das nichts an dieser
UI ändert) — als Fund für Paket 6 ("UX und Store") oder einen eigenen
kleinen Nachzieh-Schritt vermerkt, nicht stillschweigend übernommen.

## Nicht übersetzte Begriffe (bewusst)

- **„Smart Lists"** — bleibt in DE, EN und FR unverändert; wird bereits im
  Deutschen als Produktname behandelt, nicht als beschreibender Begriff
  übersetzt.
- **„Sync"** (kurze Form, z. B. Einstellungen-Kachel) — bleibt in allen drei
  Sprachen „Sync"; „Synchronisation"/„Synchronisation iCloud" wird an den
  längeren, erklärenden Stellen verwendet (z. B. „iCloud-Sync" →
  „Synchronisation iCloud").
