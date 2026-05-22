import WidgetKit
import SwiftUI
import AppIntents

struct EpisodeWidgetEntry: TimelineEntry {
    let date: Date
    let kind: WidgetEpisodeKind
    let selectedCatalogID: String?
    let selectedCatalogName: String
    let episode: WidgetEpisodeSnapshot?
    let libraryTitle: String
    let coverImage: UIImage?
}

private struct EpisodeWidgetDisplayContext {
    let title: String
    let subtitle: String
    let symbolName: String
    let emptyMessage: String
}

struct EpisodeWidgetProvider: AppIntentTimelineProvider {
    let kind: WidgetEpisodeKind

    func placeholder(in context: Context) -> EpisodeWidgetEntry {
        EpisodeWidgetEntry.placeholder(for: kind)
    }

    func snapshot(for configuration: EpisodeWidgetConfigurationIntent, in context: Context) async -> EpisodeWidgetEntry {
        makeEntry(for: configuration, date: .now)
    }

    func timeline(for configuration: EpisodeWidgetConfigurationIntent, in context: Context) async -> Timeline<EpisodeWidgetEntry> {
        let current = makeEntry(for: configuration, date: .now)
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: current.date) ?? current.date.addingTimeInterval(3600)
        return Timeline(entries: [current], policy: .after(refresh))
    }

    private func makeEntry(for configuration: EpisodeWidgetConfigurationIntent, date: Date) -> EpisodeWidgetEntry {
        let selectedCatalog = configuration.catalog ?? WidgetCatalogSelection.allValue
        let selectedCatalogName = WidgetEpisodeLogic.selectedCatalogName(for: selectedCatalog)
        let snapshot = WidgetSnapshotStore.load()
        let refreshToken = WidgetSnapshotStore.randomRefreshToken(for: selectedCatalog)
        let episode = snapshot.flatMap {
            WidgetEpisodeLogic.episode(
                for: kind,
                catalogID: selectedCatalog,
                at: date,
                refreshToken: refreshToken,
                snapshot: $0
            )
        }

        let coverImage = episode?.coverImageName.flatMap { WidgetSnapshotStore.coverImage(named: $0) }

        return EpisodeWidgetEntry(
            date: date,
            kind: kind,
            selectedCatalogID: selectedCatalog,
            selectedCatalogName: selectedCatalogName,
            episode: episode,
            libraryTitle: snapshot?.libraryTitle ?? "HörspielLog",
            coverImage: coverImage
        )
    }
}

struct EpisodeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EpisodeWidgetEntry

    private var isSmall: Bool {
        family == .systemSmall
    }

    private var displayContext: EpisodeWidgetDisplayContext {
        EpisodeWidgetDisplayContext(
            title: widgetTitle,
            subtitle: widgetSubtitle,
            symbolName: widgetSymbolName,
            emptyMessage: widgetEmptyMessage
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 10 : 14) {
            WidgetHeaderView(
                title: displayContext.title,
                subtitle: displayContext.subtitle,
                symbolName: displayContext.symbolName,
                compact: isSmall,
                shuffleCatalogID: entry.kind == .random ? entry.selectedCatalogID : nil
            )

            if let episode = entry.episode {
                EpisodeWidgetCard(
                    entry: entry,
                    episode: episode,
                    isSmall: isSmall
                )
            } else {
                EmptyEpisodeWidgetCard(title: "Nichts gefunden", message: displayContext.emptyMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetCoverBackground(family: family, coverImage: entry.coverImage)
        }
    }

    private var widgetTitle: String {
        if isSmall {
            switch entry.kind {
            case .upNext: return "Nächste"
            case .random: return "Zufällig"
            }
        }

        switch entry.kind {
        case .upNext: return "Als Nächstes"
        case .random: return "Zufällige Folge"
        }
    }

    private var widgetSubtitle: String {
        guard !isSmall else { return "" }
        if entry.selectedCatalogName == "Alle Kataloge" {
            return entry.libraryTitle
        }
        return entry.selectedCatalogName
    }

    private var widgetSymbolName: String {
        switch entry.kind {
        case .upNext: return "play.circle.fill"
        case .random: return "shuffle.circle.fill"
        }
    }

    private var widgetEmptyMessage: String {
        switch entry.kind {
        case .upNext:
            return "Für diese Auswahl gibt es gerade keine offene Fortsetzung."
        case .random:
            return "Für diese Auswahl ist noch keine Folge verfügbar."
        }
    }
}

private struct EpisodeWidgetCard: View {
    let entry: EpisodeWidgetEntry
    let episode: WidgetEpisodeSnapshot
    let isSmall: Bool

    var body: some View {
        Group {
            if isSmall {
                SmallEpisodeWidgetCard(entry: entry, episode: episode)
            } else {
                MediumEpisodeWidgetCard(entry: entry, episode: episode)
            }
        }
    }
}

private struct WidgetHeaderView: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let compact: Bool
    let shuffleCatalogID: String?

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 8 : 10) {
            HStack(spacing: compact ? 6 : 8) {
                Image(systemName: symbolName)
                    .font(compact ? .subheadline.weight(.semibold) : .title2)
                    .foregroundStyle(.tint)

                if compact {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if !compact {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let shuffleCatalogID {
                Button(intent: ShuffleRandomEpisodeIntent(catalogID: shuffleCatalogID)) {
                    Image(systemName: "shuffle")
                        .font(compact ? .caption2.weight(.bold) : .body.weight(.semibold))
                        .padding(compact ? 5 : 0)
                        .background(
                            compact ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear),
                            in: Circle()
                        )
                }
                .buttonStyle(.borderless)
                .tint(.accentColor)
            }
        }
    }
}

private struct SmallEpisodeWidgetCard: View {
    let entry: EpisodeWidgetEntry
    let episode: WidgetEpisodeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primaryTitle)
                .font(.body.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            if let universeName = episode.universeName {
                Text(universeName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 2)

            HStack(alignment: .center, spacing: 6) {
                Text("\(episode.episodeNumber)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: Capsule())

                CompactFooterMetaRow(episode: episode)

                Spacer(minLength: 0)

                SmallStatusText(label: statusLabel)
            }
        }
    }

    private var primaryTitle: String {
        episode.title.isEmpty ? "Unbenannte Folge" : episode.title
    }

    private var statusLabel: String {
        switch entry.kind {
        case .upNext: "Weiter"
        case .random: episode.isListened ? "Gehört" : "Offen"
        }
    }
}

private struct MediumEpisodeWidgetCard: View {
    let entry: EpisodeWidgetEntry
    let episode: WidgetEpisodeSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let universeName = episode.universeName {
                        Text(universeName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text("\(episode.episodeNumber)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.12), in: Capsule())
                }

                Text(titleText)
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)

                Spacer(minLength: 4)

                HStack(alignment: .center) {
                    FooterMetaRow(episode: episode)
                    Spacer(minLength: 8)
                    StatusPill(
                        label: statusLabel,
                        emphasized: !episode.isListened || entry.kind == .upNext
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            if let image = entry.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var titleText: String {
        episode.title.isEmpty ? "Unbenannte Folge" : episode.title
    }

    private var statusLabel: String {
        switch entry.kind {
        case .upNext: "Als Nächstes"
        case .random: episode.isListened ? "Schon gehört" : "Noch offen"
        }
    }
}

private struct EmptyEpisodeWidgetCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct FooterMetaRow: View {
    let episode: WidgetEpisodeSnapshot

    var body: some View {
        HStack(spacing: 8) {
            if episode.releaseYear > 0 {
                Label(String(episode.releaseYear), systemImage: "calendar")
            }

            if episode.isListened, let listenedAt = episode.lastListenedAt {
                Label(
                    listenedAt.formatted(.dateTime.day().month(.abbreviated)),
                    systemImage: "checkmark.circle"
                )
            } else if !episode.isListened {
                Label("Offen", systemImage: "circle")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
}

private struct CompactFooterMetaRow: View {
    let episode: WidgetEpisodeSnapshot

    var body: some View {
        HStack(spacing: 8) {
            if episode.releaseYear > 0 {
                Text(String(episode.releaseYear))
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct SmallStatusText: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

private struct StatusPill: View {
    let label: String
    let emphasized: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(emphasized ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                emphasized ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.quaternary),
                in: Capsule()
            )
    }
}

private struct RatingBadge: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text("\(rating)/5")
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.medium))
    }
}

struct ShuffleRandomEpisodeIntent: AppIntent {
    static var title: LocalizedStringResource = "Zufällige Folge neu mischen"

    @Parameter(title: "Katalog")
    var catalogID: String?

    init() {}

    init(catalogID: String?) {
        self.catalogID = catalogID
    }

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.bumpRandomRefreshToken(for: catalogID)
        return .result()
    }
}

private struct WidgetCoverBackground: View {
    let family: WidgetFamily
    let coverImage: UIImage?

    var body: some View {
        if family == .systemSmall, let image = coverImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .opacity(0.2)
                .overlay(Color(.systemBackground).opacity(0.6))
        } else {
            Color(.systemBackground).opacity(0.001)
        }
    }
}

struct UpNextEpisodeWidget: Widget {
    let kind: String = "UpNextEpisodeWidget"

    var body: some WidgetConfiguration {
        EpisodeWidgetConfiguration.make(
            kind: kind,
            widgetKind: .upNext,
            displayName: "Als Nächstes",
            description: "Zeigt dir eine passende nächste Folge aus einem Katalog oder aus allen Katalogen."
        )
    }
}

struct RandomEpisodeWidget: Widget {
    let kind: String = "RandomEpisodeWidget"

    var body: some WidgetConfiguration {
        EpisodeWidgetConfiguration.make(
            kind: kind,
            widgetKind: .random,
            displayName: "Zufällige Folge",
            description: "Wählt stündlich eine zufällige Folge aus einem Katalog oder aus allen Katalogen."
        )
    }
}

@main
struct EpisodeTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpNextEpisodeWidget()
        RandomEpisodeWidget()
    }
}

private enum EpisodeWidgetConfiguration {
    static func make(
        kind: String,
        widgetKind: WidgetEpisodeKind,
        displayName: String,
        description: String
    ) -> some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EpisodeWidgetConfigurationIntent.self,
            provider: EpisodeWidgetProvider(kind: widgetKind)
        ) { entry in
            EpisodeWidgetView(entry: entry)
        }
        .configurationDisplayName(displayName)
        .description(description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension EpisodeWidgetEntry {
    static func placeholder(for kind: WidgetEpisodeKind) -> EpisodeWidgetEntry {
        EpisodeWidgetEntry(
            date: .now,
            kind: kind,
            selectedCatalogID: WidgetCatalogSelection.allValue,
            selectedCatalogName: "Alle Kataloge",
            episode: WidgetEpisodeSnapshot(
                id: UUID(),
                episodeNumber: 7,
                title: "und der unheimliche Drache",
                releaseYear: 1979,
                universeName: "Die drei ???",
                isListened: false,
                rating: 4,
                lastListenedAt: nil,
                coverImageName: nil
            ),
            libraryTitle: "HörspielLog",
            coverImage: nil
        )
    }
}
