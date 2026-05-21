# Vertical-Slice-Leitplanken V1.6

## Ziel

Eine hybride Ordnerstruktur einführen, die klar abgrenzbare Features in eigene Slices trennt, während geteilte Domain-Modelle und App-Infrastruktur in begrenzten Shared-Bereichen leben. Katalog als Pilot-Slice.

## Zielstruktur

```
EpisodeTracker/
├── Features/
│   └── Catalog/
│       ├── CatalogModels.swift
│       ├── CatalogParser.swift
│       ├── CatalogCacheStore.swift
│       ├── CatalogRemoteDataSource.swift
│       ├── EpisodeCatalog.swift
│       ├── ActiveCatalogStore.swift
│       ├── CatalogUpdateBannerRow.swift
│       └── CatalogUpdateBannerView.swift
├── Shared/
│   ├── Models/
│   │   ├── Episode.swift
│   │   ├── Mood.swift
│   │   ├── Universe.swift
│   │   └── StreamingService.swift
│   └── App/
│       ├── EpisodeTrackerApp.swift
│       ├── AppDataBootstrapper.swift
│       ├── AppModelContainerFactory.swift
│       ├── AppContainerAccess.swift
│       ├── SchemaVersions.swift
│       ├── EpisodeTrackerMigrationPlan.swift
│       ├── BootstrapReport.swift
│       └── FreemiumAccess.swift
├── ContentView.swift              (bleibt, orchestriert Features)
├── EpisodeListView.swift          (bleibt)
├── EpisodeEditView.swift          (bleibt)
├── SettingsView.swift             (bleibt)
├── StatisticsView.swift           (bleibt)
├── ...                            (restliche Dateien bleiben)
```

## Regeln

1. **Feature-Ordner ab 3+ Dateien** mit gemeinsamer Verantwortung, ohne direkte Abhängigkeit zu Haupt-Views.
2. **Features dürfen auf Shared zugreifen**, aber nie aufeinander.
3. **Shared/Models** enthält nur SwiftData-Entitäten und zugehörige Enums die von mehr als einem Feature genutzt werden.
4. **Shared/App** enthält nur Startup-Infrastruktur und App-weite Konfiguration.
5. **Nicht zugeordnete Dateien bleiben** an Ort und Stelle — kein Misc-Ordner.
6. **Nur Verschieben, nicht umschreiben** — keine neuen Abstraktionen oder Protokolle in diesem Schritt.

## Katalog-Slice: Dateien-Zuordnung

### Nach Features/Catalog/ verschieben

| Datei | Aktueller Ort | Anmerkung |
|---|---|---|
| CatalogModels.swift | Root | |
| CatalogParser.swift | Root | |
| CatalogCacheStore.swift | Root | |
| CatalogRemoteDataSource.swift | Root | |
| EpisodeCatalog.swift | EpisodeTracker/ | |
| ActiveCatalogStore.swift | EpisodeTracker/ | |
| CatalogUpdateBannerRow.swift | (neu, aus EpisodeListView extrahiert) | |
| CatalogUpdateBannerView.swift | (neu, aus EpisodeListView extrahiert) | |

### Nach Shared/Models/ verschieben

Episode.swift, Mood.swift, Universe.swift, StreamingService.swift

### Nach Shared/App/ verschieben

EpisodeTrackerApp.swift, AppDataBootstrapper.swift, AppModelContainerFactory.swift, AppContainerAccess.swift, SchemaVersions.swift, EpisodeTrackerMigrationPlan.swift, BootstrapReport.swift, FreemiumAccess.swift

## Was sich NICHT ändert

- Keine Datei wird inhaltlich umgeschrieben
- SettingsView enthält Katalog-Einstellungen und greift auf EpisodeCatalog zu — das ist ok, sie orchestriert
- ContentView, EpisodeListView bleiben wo sie sind
- Sync/Migration, Cover, SmartList bleiben flach
- Keine neuen Protokolle, Dependency Injection Container oder Abstraktionsschichten

## Xcode-Projekt

Dateiverschiebungen müssen im Xcode-Projekt (pbxproj) reflektiert werden. Gruppen in Xcode müssen den neuen Ordnerpfaden entsprechen.

## Testbarkeit

Die Banner-Views sind bereits als reine Display-Layer testbar (Recommendation als Parameter). Dieses Muster — Daten von außen, View nur Display — gilt als Leitbild für zukünftige Slice-Extraktionen.

## Spätere Slices (nicht V1.6)

- **Features/Cover/** — CoverImageStore, CoverImageCache, CoverImageView, EpisodeCoverManager
- **Features/Sync/** — SyncPreparation, SyncMigrationSupport, CloudSyncRepairObserverView
- **Features/SmartList/** — SmartListDefinition, SmartListDetailView, UpNextView
