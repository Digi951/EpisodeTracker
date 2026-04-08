# EpisodeTracker

A native iOS app for tracking and managing episodes of German audio dramas (*Hörspiele*). Built with SwiftUI and SwiftData, with first-class support for **Die drei ???** and other Europa series.

## Features

- **Episode list** — searchable, sortable (by number, title, or rating), filterable by listened status, universe, and mood
- **Mood filter chip bar** — horizontal scrollable chips at the top of the list for one-tap mood filtering
- **Episode detail & edit** — personal notes, 1–5 star rating, mood tags, listened toggle, listen counter
- **Auto-fill from catalog** — enter an episode number and the title + release year are suggested automatically
- **Remote catalog sync** — episode lists are fetched from GitHub, cached on disk, and refreshed with HTTP ETag/`If-Modified-Since` (at most every 6 hours)
- **Multiple universes** — organise episodes into separate series (Die drei ???, Bibi Blocksberg, …)
- **Mood management** — six default moods seeded on first launch; add or remove moods in Settings
- **Statistics** — total episodes, listened count, average rating, top-rated episodes, mood distribution
- **JSON backup** — export and re-import all user data as a portable JSON file
- **App icon** — light, dark, and tinted variants

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.3 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Minimum OS | iOS 26 |
| Dependencies | None (no third-party packages) |

## Architecture

```
EpisodeTracker/
├── EpisodeTracker/          # App target
│   ├── Episode.swift        # SwiftData model – episode with all tracking fields
│   ├── Mood.swift           # SwiftData model – mood tag (many-to-many with Episode)
│   ├── Universe.swift       # SwiftData model – series / collection container
│   ├── EpisodeCatalog.swift # @MainActor singleton – coordinates catalog cache & refresh
│   ├── EpisodeListView.swift
│   ├── EpisodeDetailView.swift
│   ├── EpisodeEditView.swift
│   ├── StatisticsView.swift
│   ├── ContentView.swift    # TabView root (Folgen · Statistiken · Einstellungen)
│   ├── EpisodeTrackerApp.swift  # ModelContainer setup + seeding
│   └── PrivacyInfo.xcprivacy
│
├── CatalogModels.swift      # CatalogEntry, ManagedCatalogSource, RemoteCatalogMetadata
├── CatalogParser.swift      # Decodes flat-array and wrapped JSON catalog formats
├── CatalogCacheStore.swift  # Disk cache for remote catalogs + bundled fallback
├── CatalogRemoteDataSource.swift  # Conditional HTTP fetch (ETag / If-Modified-Since)
├── SettingsView.swift       # Universe/mood management, catalog import, backup
└── KeyboardDismissModifier.swift
```

## Catalog System

Episode catalogs are JSON arrays hosted on GitHub and fetched at runtime:

| Universe | Source |
|---|---|
| Die drei ??? | `github.com/Digi951/Episodes-The_three_questionmarks` |
| Die drei ??? Kids | `github.com/Digi951/Episodes-The_three_questionmarks_kids` |
| Die drei !!! | `github.com/Digi951/Episodes-The_tree_exclamationmarks` |
| Bibi Blocksberg | `github.com/Digi951/Episodes-Bibi_Blocksberg` |

**Caching strategy:**

1. On first launch the bundled `EpisodeCatalog.json` (240 episodes, Die drei ???) is used immediately — no network required.
2. In the background, the app fetches each source with `If-None-Match` / `If-Modified-Since` headers. A `304 Not Modified` response costs only one round-trip with no body.
3. Updated data is written to disk (`Application Support/EpisodeTracker/RemoteCatalogs/`).
4. Subsequent launches load from disk cache; a fresh network check happens at most every **6 hours**.
5. Network failures are silent — existing cached data is preserved unchanged.

## Default Moods

Seeded automatically on first launch:

| Mood | Icon |
|---|---|
| Gruselig | 😱 |
| Spannend | ⚡ |
| Witzig | 😄 |
| Nachdenklich | 🧠 |
| Klassiker | ⭐ |
| Abenteuer | 🧭 |

Custom moods (name + emoji) can be added and deleted in **Einstellungen → Stimmung hinzufügen**.

## Getting Started

1. Clone the repository
2. Open `EpisodeTracker.xcodeproj` in Xcode 26+
3. Select a simulator or device running iOS 26+
4. Build and run (`⌘R`)

No additional setup required. The app seeds universes and default moods on first launch and fetches the latest episode catalogs in the background.

## App Store Readiness

- `PrivacyInfo.xcprivacy` declares `UserDefaults` access (`CA92.1`) — required by Apple since Spring 2024
- No third-party SDKs, no analytics, no user data leaves the device (catalog fetch is read-only)
- A **Privacy Policy URL** must be provided in App Store Connect (even for data-free apps)
- Suggested category: **Entertainment**, age rating **4+**

## Backup Format

The JSON backup contains three top-level arrays:

```json
{
  "exportedAt": "2026-04-08T...",
  "schemaVersion": 1,
  "collections": [{ "name": "Die drei ???" }],
  "moods": [{ "name": "Gruselig", "iconName": "😱" }],
  "episodes": [{
    "episodeNumber": 1,
    "title": "und der Super-Papagei",
    "releaseYear": 1979,
    "isListened": true,
    "rating": 5,
    "listenCount": 3,
    "collectionName": "Die drei ???",
    "moodNames": ["Klassiker", "Spannend"]
  }]
}
```

Backups can be re-imported via **Einstellungen → Backup importieren** and are merged non-destructively (existing episodes are updated; missing episodes are created).
