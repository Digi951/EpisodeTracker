# App Store Notes

## App Information

- Name: HörspielLog
- Subtitle: Hörspiele einfach merken
- Bundle ID: `com.Digi.EpisodeTracker`
- Primary category: Entertainment
- Age rating target: 4+
- Initial availability: Germany
- Initial distribution: TestFlight first

## Privacy

- Marketing URL: `https://digi951.github.io/hoerspiellog-site/`
- Privacy Policy URL: `https://digi951.github.io/hoerspiellog-site/privacy/`
- Support URL: `https://digi951.github.io/hoerspiellog-site/support/`
- App Privacy answer: The app does not collect data.
- Privacy choices URL: not needed.

GitHub Pages site lives in the separate `Digi951/hoerspiellog-site` repository.

## App Store Copy

### Subtitle

Hörspiele einfach merken

### Promotional Text

Behalte den Überblick über gehörte Folgen, Bewertungen und persönliche Notizen deiner Hörspiel-Sammlung.

### Description

HörspielLog hilft dir, deine Hörspiel-Folgen übersichtlich zu verwalten.

Markiere Folgen als gehört, vergib Bewertungen, notiere persönliche Eindrücke und filtere deine Sammlung nach Katalog, Stimmung oder Hörstatus.

Für viele beliebte Reihen sind Folgenlisten bereits vorbereitet – darunter Die drei ???, TKKG, Bibi Blocksberg, Benjamin Blümchen und Fünf Freunde. Diese Kataloge lassen sich einzeln aktivieren und über öffentliche JSON-Listen aktualisieren, sodass neue Reihen und Folgen auch ohne App-Update verfügbar werden.

Jede Folge lässt sich mit einem Tippen direkt in Spotify oder Apple Music öffnen – für viele Folgen sind die passenden Verknüpfungen schon hinterlegt. Den bevorzugten Dienst wählst du in den Einstellungen.

Die App stellt selbst keine Audioinhalte bereit, spielt keine Hörspiele ab und ist nicht mit Hörspiel-Verlagen oder Markeninhabern verbunden. Deine eigenen Einträge, Bewertungen, Notizen und Backups bleiben auf deinem Gerät, sofern du sie nicht selbst exportierst.

### Keywords

Hörspiele,Folgen,Tracker,Sammlung,Bewertung,Notizen,Katalog

### What's New (Version 1.6)

Diese Version macht das Pflegen deiner Sammlung ein gutes Stück angenehmer.

• Cover direkt einfügen: Hast du ein Cover kopiert? Zum Beispiel als Screenshot aus deinem Streamingdienst? Dann setzt du es jetzt mit einem Tippen aus der Zwischenablage in die Folge ein. Der Umweg über die Fotos-App entfällt.

• Neue Folgen im Blick: Bekommt einer deiner aktiven Kataloge Nachschub, weist dich ein dezenter Hinweis direkt an Ort und Stelle darauf hin.

• Verlässlicher bei Updates: Deine Folgen-Cover und Stimmungen bleiben beim App-Update jetzt noch zuverlässiger erhalten.

Dazu kommen viele Feinschliffe in der Folgenliste und unter der Haube. Danke, dass du HörspielLog nutzt. Viel Freude beim Hören!

## Future Freemium Model

Version 1.0 should launch free and without In-App Purchases. Add StoreKit only after TestFlight feedback confirms the right product boundary.

Recommended In-App Purchase:

- Type: Non-Consumable
- Reference name: HörspielLog Pro
- Product ID: `com.Digi.EpisodeTracker.pro`

Free:

- Up to 25 manually created episodes
- 1 custom catalog
- Predefined remote catalogs
- Basic statistics

Pro:

- Unlimited manually created episodes
- Multiple custom catalogs
- Backup export/import
- Extended statistics

## Version 1.1

Initial focus:

- Enable native iPad distribution.
- Add a native iPad split view for the episode list and detail screen.
- Keep the existing iPhone navigation and data model stable.
- Review iPad screenshots in TestFlight before adding larger split-view navigation.
- Avoid adding paid features until the free 1.0 review concern is fully resolved.

## Review Notes Draft

HörspielLog is a private tracking app for audio drama episodes. User-created episodes, notes, ratings, moods, and backups remain on device unless the user manually exports a backup. The app can fetch public remote catalog JSON files over HTTPS to keep episode lists current without requiring an app update. The app does not provide audio content and is not affiliated with any audio drama publisher or trademark owner.

### Version 1.1 Review Notes

Version 1.1 adds native iPad support and layout improvements for larger screens. The update introduces an iPad split view for browsing episodes and viewing episode details side by side, while keeping the existing iPhone experience unchanged.

This update does not add subscriptions, paid digital content, external purchase flows, audio playback, audio files, streaming access, or externally unlocked features. HörspielLog remains a free private tracking app. Remote catalog files are public HTTPS JSON metadata only and contain episode titles, ordering information, and related catalog metadata to help users create their own local tracking entries.

### What's New (Version 1.7)

Diese Version gibt der App eine persönlichere Note und macht die Cover-Ansicht deutlich schöner.

• Deine Farbe wählen: In den Einstellungen wählst du jetzt aus sechs Akzentfarben – Blau, Indigo, Lila, Teal, Grün oder Rot. Die gewählte Farbe zieht sich durch die ganze App.

• Neue Detailansicht: Das Cover einer Folge füllt jetzt den gesamten Hintergrund aus – weich unscharf und getönt. Bewertung, Stimmungen und Notiz liegen auf einer klaren Glasfläche davor.

• Platzhalter in der Folgenliste: Sobald mindestens eine Folge ein Cover hat, zeigen alle anderen Folgen ein kleines Serien-Initial als Platzhalter – die Liste wirkt damit einheitlicher.

• iPad zuverlässiger: Bibliothek und „Als nächstes" nutzen auf dem iPad jetzt vollständig die Splitscreen-Ansicht. Ein Tipp auf eine Folge öffnet sie direkt in der Detailspalte.

Danke, dass du HörspielLog nutzt. Viel Freude beim Hören!

### Version 1.6 Review Notes

Version 1.6 is mainly an internal update: a cleaner project structure, more robust data migration and deduplication, and small convenience improvements such as pasting a cover image from the clipboard and a contextual hint when a subscribed catalog has new episodes.

HörspielLog remains a free private tracking app for audio drama episodes. This version does not add subscriptions, In-App Purchases, external purchase flows, audio playback, audio files, or externally unlocked features.

Note on streaming links: HörspielLog can show an optional link on an episode that opens that episode in the user's own Spotify or Apple Music app. The app itself does not play, stream, host, or bundle any audio and provides no audio content. These links are convenience deep-links into third-party apps the user already has installed; choosing Spotify or Apple Music is a preference in Settings. The predefined catalog files remain public HTTPS JSON metadata only (episode titles, ordering information, and the corresponding external link).

User-created episodes, notes, ratings, moods, and backups remain on device unless the user manually exports a backup. HörspielLog is not affiliated with any audio drama publisher or trademark owner.

### Guideline 2.1(b) Business Model Reply

Thank you for reviewing HörspielLog.

HörspielLog does not currently offer paid subscriptions, paid digital content, or externally unlocked paid features. Version 1.0 is a free private tracking app for audio drama episodes. Users can manually create and manage their own episode entries, ratings, notes, moods, and local backup files.

The app can access public catalog JSON files over HTTPS. These catalogs contain metadata only, such as episode titles and ordering information, so users can add entries more conveniently. The app does not provide audio playback, audio files, publisher subscriptions, streaming access, or any paid media content.

Answers to the requested questions:

1. No users can use paid subscriptions in the app because HörspielLog does not currently include any paid subscriptions.
2. Users cannot purchase subscriptions for this app at this time. There is no external purchase flow and no active In-App Purchase in version 1.0.
3. Users cannot access any previously purchased subscriptions in HörspielLog.
4. No paid content, subscriptions, or paid features are unlocked outside In-App Purchase. All current version 1.0 functionality is available for free.

## Upload Checklist

- [x] App icon is configured.
- [x] Display name is `HörspielLog`.
- [x] Bundle ID is `com.Digi.EpisodeTracker`.
- [x] Minimum OS is iOS 17.0.
- [x] Privacy manifest is present.
- [x] Privacy, support, website, manifest, and catalog URLs return HTTP 200.
- [x] Device build succeeds with code signing disabled.
- [x] Unit tests pass.
- [ ] Create or confirm the App Store Connect app record.
- [ ] Archive with real signing in Xcode.
- [ ] Upload build to TestFlight.
- [ ] Add screenshots before App Store submission.
