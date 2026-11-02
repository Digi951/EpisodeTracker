import SwiftUI
import SwiftData

/// Rückblick „Dein Hörjahr“ als Sheet aus der Statistik. Aufbau wie der
/// Jahresrückblick in BoardGameLog: dasselbe Poster auf dem Bildschirm und
/// mit fester Breite für das geteilte Bild.
/// Jahr für `.sheet(item:)`.
struct YearInReviewSelection: Identifiable {
    let year: Int
    var id: Int { year }
}

struct YearInReviewView: View {
    let episodes: [Episode]

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    @State private var selectedYear: Int
    @State private var renderedImage: Image?

    static let exportWidth: CGFloat = 800

    init(episodes: [Episode], year: Int) {
        self.episodes = episodes
        _selectedYear = State(initialValue: year)
    }

    private var accentColor: Color { AppAccentColor.resolved(from: appAccentColorRawValue).color }

    private var availableYears: [Int] {
        let years = YearInReviewEngine.availableYears(episodes: episodes)
        return years.contains(selectedYear) ? years : (years + [selectedYear]).sorted()
    }

    private var engine: YearInReviewEngine {
        YearInReviewEngine(episodes: episodes, year: selectedYear)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    yearSwitcher
                    YearInReviewPoster(engine: engine, accentColor: accentColor)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(YearInReviewPoster.background(accentColor: accentColor).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Fertig")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
            }
            // Bild vorab rendern, damit „Teilen“ beim ersten Tippen öffnet.
            .task(id: selectedYear) { render() }
        }
    }

    private var yearSwitcher: some View {
        let years = availableYears
        let index = years.firstIndex(of: selectedYear) ?? 0

        return HStack(spacing: 24) {
            Button {
                if index > 0 { selectedYear = years[index - 1] }
            } label: {
                YearArrow(systemImage: "chevron.left")
            }
            .accessibilityLabel(String(localized: "YearInReview.PreviousYear", defaultValue: "Vorheriges Jahr"))
            // Ausgeblendet statt abgeblendet: Ein blasser Pfeil wirkt kaputt.
            .opacity(index == 0 ? 0 : 1)
            .disabled(index == 0)

            // `String(year)`, nicht `Text("\(year)")`: sonst „2.026“.
            Text(verbatim: String(selectedYear))
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)

            Button {
                if index < years.count - 1 { selectedYear = years[index + 1] }
            } label: {
                YearArrow(systemImage: "chevron.right")
            }
            .accessibilityLabel(String(localized: "YearInReview.NextYear", defaultValue: "Nächstes Jahr"))
            .opacity(index >= years.count - 1 ? 0 : 1)
            .disabled(index >= years.count - 1)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        let label = Label(String(localized: "YearInReview.Share", defaultValue: "Teilen"), systemImage: "square.and.arrow.up")
        if let renderedImage {
            ShareLink(
                item: renderedImage,
                preview: SharePreview(YearInReviewPoster.title(year: selectedYear), image: renderedImage)
            ) {
                label
            }
        }
    }

    /// `ShareLink` braucht das fertige Bild schon beim Anzeigen.
    @MainActor
    private func render() {
        renderedImage = nil
        guard engine.episodeCount > 0 else { return }
        let content = YearInReviewPoster(engine: engine, accentColor: accentColor, width: Self.exportWidth)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let uiImage = renderer.uiImage else { return }
        renderedImage = Image(uiImage: uiImage)
    }
}

/// Inhalt des Rückblicks, auf dem Bildschirm ohne feste Breite und für den
/// Export mit `exportWidth`.
struct YearInReviewPoster: View {
    let engine: YearInReviewEngine
    let accentColor: Color
    var width: CGFloat?
    // Der Export rendert außerhalb der View-Hierarchie mit Standardgröße,
    // deshalb wechselt nur die Bildschirmfassung auf eine Spalte.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func title(year: Int) -> String {
        AppLocalization.format("YearInReview.Title", defaultValue: "Dein Hörjahr %@", String(year))
    }

    /// Akzentfarbe mit dunklem Verlauf darüber, damit weißer Text auch auf
    /// hellen Akzentfarben (Bernstein, Teal) lesbar bleibt.
    static func background(accentColor: Color) -> some View {
        accentColor
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.25), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(Self.title(year: engine.year))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            if engine.episodeCount == 0 {
                Text(AppLocalization.format(
                    "YearInReview.Empty",
                    defaultValue: "Für %@ hast du noch keine Folge als gehört eingetragen.",
                    String(engine.year)
                ))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                hero
                tileGrid
                if engine.podium.count >= 2 {
                    podium
                }
                Text(verbatim: "HörspielLog")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
        .frame(width: width, alignment: .top)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(Self.background(accentColor: accentColor))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hero: some View {
        VStack(spacing: 4) {
            Text(verbatim: String(engine.episodeCount))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(engine.episodeCount == 1
                 ? String(localized: "YearInReview.Hero.One", defaultValue: "Folge als gehört eingetragen")
                 : String(localized: "YearInReview.Hero.Other", defaultValue: "Folgen als gehört eingetragen"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    /// `Grid` statt `LazyVGrid`, damit Kacheln einer Reihe gleich hoch sind.
    private var tileGrid: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: tiles.count, by: columns).map {
            Array(tiles[$0..<min($0 + columns, tiles.count)])
        }
        return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(rows[index]) { tile in
                        YearInReviewTile(tile: tile)
                    }
                    if rows[index].count < columns {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
    }

    private var tiles: [YearInReviewTileContent] {
        var tiles: [YearInReviewTileContent] = []
        if let series = engine.favoriteSeries {
            tiles.append(YearInReviewTileContent(
                systemImage: "rectangle.stack.fill",
                title: String(localized: "YearInReview.FavoriteSeries", defaultValue: "Lieblingsreihe"),
                value: series.name,
                detail: Self.episodeCountText(series.count)
            ))
        }
        if let month = engine.strongestMonth {
            tiles.append(YearInReviewTileContent(
                systemImage: "calendar",
                title: String(localized: "YearInReview.StrongestMonth", defaultValue: "Stärkster Monat"),
                value: Calendar.current.standaloneMonthSymbols[month.month - 1],
                detail: Self.episodeCountText(month.count)
            ))
        }
        if !engine.topMoods.isEmpty {
            tiles.append(YearInReviewTileContent(
                systemImage: "theatermasks.fill",
                title: String(localized: "YearInReview.TopMoods", defaultValue: "Häufigste Stimmungen"),
                value: engine.topMoods
                    .map { [$0.mood.iconName, $0.mood.name].compactMap { $0 }.joined(separator: " ") }
                    .joined(separator: "\n"),
                detail: nil
            ))
        }
        if engine.podium.count == 1, let best = engine.podium.first {
            tiles.append(YearInReviewTileContent(
                systemImage: "star.fill",
                title: String(localized: "YearInReview.BestEpisode", defaultValue: "Beste Folge"),
                value: best.title,
                detail: AppLocalization.displayName(forUniverseName: best.universe?.name)
            ))
        }
        return tiles
    }

    /// Zweiter, erster, dritter Platz wie auf einem Siegertreppchen.
    private var podium: some View {
        let entries = engine.podium
        let order = [1, 0, 2].filter { $0 < entries.count }
        return VStack(spacing: 14) {
            Text(String(localized: "YearInReview.Podium", defaultValue: "Deine Top 3"))
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(order, id: \.self) { index in
                    PodiumStep(episode: entries[index], place: index + 1)
                }
            }
        }
    }

    static func episodeCountText(_ count: Int) -> String {
        count == 1
            ? String(localized: "YearInReview.EpisodeCount.One", defaultValue: "1 Folge")
            : AppLocalization.format("YearInReview.EpisodeCount.Other", defaultValue: "%lld Folgen", Int64(count))
    }
}

private struct YearArrow: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(.white.opacity(0.18)))
    }
}

private struct YearInReviewTileContent: Identifiable {
    let systemImage: String
    let title: String
    let value: String
    let detail: String?

    var id: String { title }
}

private struct YearInReviewTile: View {
    let tile: YearInReviewTileContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(tile.title, systemImage: tile.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(tile.value)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            if let detail = tile.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }
}

/// Eine Stufe des Treppchens. Lädt das Cover synchron aus dem Cache, damit
/// es auch im `ImageRenderer`-Export erscheint.
private struct PodiumStep: View {
    let episode: Episode
    let place: Int
    @ScaledMetric(relativeTo: .caption) private var titleHeight: CGFloat = 32

    private var coverSize: CGFloat { place == 1 ? 84 : 64 }
    private var stepHeight: CGFloat {
        switch place {
        case 1: 56
        case 2: 40
        default: 28
        }
    }

    private var coverName: String? {
        [episode.coverImageName, episode.universe?.coverImageName]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 6) {
            cover
            Text(episode.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(height: titleHeight, alignment: .top)
            Text(verbatim: "\(place)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: stepHeight)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
                        .fill(.white.opacity(place == 1 ? 0.28 : 0.16))
                )
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.format(
            "YearInReview.Podium.Place",
            defaultValue: "Platz %lld: %@",
            Int64(place),
            episode.title
        ))
    }

    @ViewBuilder
    private var cover: some View {
        if let coverName, let image = CoverImageCache.shared.image(named: coverName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: coverSize, height: coverSize)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.15))
                .frame(width: coverSize, height: coverSize)
                .overlay {
                    Image(systemName: "headphones")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }
}

/// Einstieg oben in der Statistik.
struct YearInReviewCard: View {
    let year: Int
    let episodeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.tint.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(YearInReviewPoster.title(year: year))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(AppLocalization.format(
                        "YearInReview.Card.Subtitle",
                        defaultValue: "%@ eingetragen",
                        YearInReviewPoster.episodeCountText(episodeCount)
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
