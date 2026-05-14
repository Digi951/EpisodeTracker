# App Store Connect – Vergleich V1.3

Stand: 2026-05-14

Dieses Dokument vergleicht die aktuelle App-Store-Beschreibung mit dem tatsächlichen Funktionsumfang von V1.3 und listet Handlungsbedarf für das nächste Update in App Store Connect auf.

---

## 1. Description Gap – Was fehlt in der Beschreibung

Die aktuelle Beschreibung deckt nur den V1.0-Umfang ab. Folgende Features sind in V1.3 vorhanden, aber nicht erwähnt:

| Feature | Im App Store erwähnt? | Anmerkung |
|---|---|---|
| iPad mit Split-View-Navigation | Nein | Komplett neues Geräteziel seit V1.1 |
| Smart Lists („Als nächstes") | Nein | 7 verschiedene Listen (Fortsetzen, Nächste, Lange nicht gehört, Übersprungen, Top bewertet, Zufällig, Zufällig nach Stimmung) |
| Widgets (Homescreen) | Nein | „Als nächstes" und „Zufällige Folge" mit Katalogauswahl |
| Einklappbare Gruppen / Katalogfortschritt | Nein | Für große Bibliotheken relevant |
| Darstellungsmodus (Hell/Dunkel/System) | Nein | Nutzererwartung bei modernen Apps |
| Hörzähler (Listen Counter) | Nein | Unterscheidung zu einfachem gehört/ungehört |
| Katalog-Massenübernahme | Nein | Komfortfunktion für neue Kataloge |

**Empfehlung:** Beschreibung komplett überarbeiten und die Smart Lists sowie iPad-Unterstützung prominent hervorheben – das sind die stärksten Differenzierungsmerkmale.

Vorschlag für eine neue Beschreibung:

> HörspielLog hilft dir, deine Hörspiel-Folgen übersichtlich zu verwalten – auf iPhone und iPad.
>
> Markiere Folgen als gehört, vergib Bewertungen und notiere persönliche Eindrücke. Smarte Listen wie „Als nächstes", „Lange nicht gehört" oder „Top bewertet" zeigen dir immer die passende Folge. Widgets bringen deine nächste Folge direkt auf den Homescreen.
>
> Filtere deine Sammlung nach Katalog, Stimmung oder Hörstatus. Vordefinierte Kataloge können über öffentliche JSON-Listen aktualisiert werden, damit neue Folgen auch ohne App-Update verfügbar werden. Große Bibliotheken bleiben dank einklappbarer Gruppen und Fortschrittsanzeige übersichtlich.
>
> Die App stellt keine Audioinhalte bereit und ist nicht mit Hörspiel-Verlagen oder Markeninhabern verbunden. Deine Einträge, Bewertungen, Notizen und Backups bleiben auf deinem Gerät.

---

## 2. Keywords – Ergänzungsvorschläge

Aktuell (49 Zeichen von 100):
```
Hörspiele,Folgen,Tracker,Sammlung,Bewertung,Notizen,Katalog
```

Vorschlag (97 Zeichen):
```
Hörspiele,Folgen,Tracker,Sammlung,Bewertung,Widget,iPad,Smart List,Katalog,Hörbuch,Drei Fragezeichen
```

Änderungen:
- **Hinzugefügt:** `Widget`, `iPad`, `Smart List`, `Hörbuch`, `Drei Fragezeichen`
- **Entfernt:** `Notizen` (geringeres Suchvolumen, in Beschreibung abgedeckt)
- `Hörbuch` fängt verwandte Suchanfragen ab
- `Drei Fragezeichen` ist das populärste deutschsprachige Hörspiel-Franchise und ein wahrscheinlicher Suchbegriff

---

## 3. Screenshots – Was fehlt

### Aktuell vorhanden
- iPhone-Screenshots aus V1.0

### Benötigt für V1.3

**iPhone (6.7" und 6.1"):**
- [ ] Episode-Liste mit einklappbaren Gruppen und Katalogfortschritt
- [ ] Smart-List-Ansicht („Als nächstes")
- [ ] Widget auf dem Homescreen (Mockup oder Screenshot)
- [ ] Darstellungsmodus Dunkel

**iPad (12.9" und 11"):**
- [ ] Split-View mit Katalogliste links und Episodendetail rechts
- [ ] Smart Lists auf iPad
- [ ] Einklappbare Gruppen auf iPad

**Hinweis:** iPad-Screenshots sind seit V1.1 Pflicht, da die App als iPad-kompatibel verteilt wird. Ohne iPad-Screenshots kann App Store Connect die Einreichung ablehnen.

---

## 4. Review Notes – Aktualisierungsbedarf

Die aktuellen Review Notes beziehen sich auf V1.1 (iPad-Update). Für V1.3 sollten sie erweitert werden:

### Vorschlag Review Notes V1.3

> HörspielLog is a private tracking app for audio drama episodes. User-created episodes, notes, ratings, moods, and backups remain on device unless the user manually exports a backup. The app can fetch public remote catalog JSON files over HTTPS to keep episode lists current without requiring an app update. The app does not provide audio content and is not affiliated with any audio drama publisher or trademark owner.
>
> Version 1.3 adds Smart Lists ("Als nächstes") with seven curated list types, Home Screen widgets for quick episode access, collapsible library groups with progress tracking, and a Light/Dark/System appearance setting. The app continues to be free with no subscriptions, paid content, or external purchase flows.
>
> Widgets display episode metadata from the user's local library and do not access network resources. Remote catalog files remain public HTTPS JSON metadata only.

---

## 5. Was weiterhin passt

| Element | Status | Anmerkung |
|---|---|---|
| App-Name: HörspielLog | Passt | Kein Änderungsbedarf |
| Subtitle: „Hörspiele einfach merken" | Passt | Kurz, treffend, deckt den Kern ab |
| Kategorie: Entertainment | Passt | Beste Wahl für Tracking-App ohne Audioinhalte |
| Altersfreigabe: 4+ | Passt | Kein problematischer Inhalt |
| Privacy: „Does not collect data" | Passt | Keine Netzwerkanalysen, kein iCloud aktiv |
| Privacy Policy URL | Passt | Seite ist aktuell |
| Support URL | Passt | Seite ist aktuell |
| Marketing URL | Prüfen | Marketing-Seite sollte V1.3-Features zeigen |
| Freemium-Modell | Nicht aktiv | Korrekt – V1.3 ist weiterhin komplett kostenlos |

---

## Zusammenfassung Handlungsbedarf

1. **Beschreibung** neu schreiben (iPad, Smart Lists, Widgets, Gruppen)
2. **Keywords** erweitern (Widget, iPad, Smart List, Hörbuch)
3. **iPad-Screenshots** erstellen (Pflicht)
4. **iPhone-Screenshots** aktualisieren (Smart Lists, Widgets, Dark Mode)
5. **Review Notes** auf V1.3 aktualisieren
6. **Marketing-Seite** prüfen und ggf. aktualisieren
