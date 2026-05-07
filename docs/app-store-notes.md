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

Markiere Folgen als gehört, vergib Bewertungen, notiere persönliche Eindrücke und filtere deine Sammlung nach Katalog, Stimmung oder Hörstatus. Vordefinierte Kataloge können über öffentliche JSON-Listen aktualisiert werden, damit neue Folgen auch ohne App-Update verfügbar werden.

Die App stellt keine Audioinhalte bereit und ist nicht mit Hörspiel-Verlagen oder Markeninhabern verbunden. Deine eigenen Einträge, Bewertungen, Notizen und Backups bleiben auf deinem Gerät, sofern du sie nicht selbst exportierst.

### Keywords

Hörspiele,Folgen,Tracker,Sammlung,Bewertung,Notizen,Katalog

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

## Review Notes Draft

HörspielLog is a private tracking app for audio drama episodes. User-created episodes, notes, ratings, moods, and backups remain on device unless the user manually exports a backup. The app can fetch public remote catalog JSON files over HTTPS to keep episode lists current without requiring an app update. The app does not provide audio content and is not affiliated with any audio drama publisher or trademark owner.

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
