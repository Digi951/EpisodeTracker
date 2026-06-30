import SwiftUI

struct StatisticsPhoneContent: View {
    let visibleSections: [StatisticsSectionKind]
    let visibleOverviewStats: [StatisticsOverviewItem]
    let topRated: [Episode]
    let moodDistribution: [(Mood, Int)]
    let moodSummaryText: String

    var body: some View {
        ForEach(visibleSections) { section in
            switch section {
            case .overview:
                Section(StatisticsSectionKind.overview.title) {
                    StatCardGrid(stats: visibleOverviewStats)
                }
            case .topRated:
                StatisticsTopRatedSection(topRated: topRated)
            case .moods:
                StatisticsMoodSection(
                    moodDistribution: moodDistribution,
                    moodSummaryText: moodSummaryText
                )
            case .chart:
                EmptyView()
            }
        }
    }
}

struct StatisticsPadContent: View {
    let layout: StatisticsRegularLayout
    let visibleSections: [StatisticsSectionKind]
    let visibleOverviewStats: [StatisticsOverviewItem]
    let topRated: [Episode]
    let moodDistribution: [(Mood, Int)]
    let moodSummaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StatisticsHeader()

            ForEach(visibleSections) { section in
                switch section {
                case .overview:
                    LazyVGrid(
                        columns: layout.summaryColumns,
                        spacing: 16
                    ) {
                        ForEach(visibleOverviewStats) { stat in
                            StatSummaryTile(stat: stat)
                        }
                    }
                case .topRated:
                    StatisticsTopRatedPanel(topRated: topRated)
                case .moods:
                    StatisticsMoodPanel(
                        moodDistribution: moodDistribution,
                        moodSummaryText: moodSummaryText
                    )
                case .chart:
                    EmptyView()
                }
            }
        }
    }
}

struct StatisticsEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("Noch keine Statistik", systemImage: "chart.bar")
        } description: {
            Text("Sobald du Folgen anlegst, siehst du hier deinen Hörstand.")
        }
    }
}

private struct StatisticsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dein Hörstand auf einen Blick")
                .font(.title3.weight(.semibold))
            Text("Die wichtigsten Zahlen und Muster deiner Sammlung, optimiert für einen schnellen Überblick.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatisticsOverviewSection: View {
    let stats: [StatisticsOverviewItem]

    var body: some View {
        Section(String(localized: "Statistics.Section.Overview", defaultValue: "Übersicht")) {
            ForEach(stats) { stat in
                StatRow(label: stat.kind.title, value: stat.value)
            }
        }
    }
}

private struct StatisticsTopRatedSection: View {
    let topRated: [Episode]

    var body: some View {
        Section(String(localized: "Statistics.Section.TopRated", defaultValue: "Beste Bewertungen")) {
            StatisticsTopRatedContent(topRated: topRated)
        }
    }
}

private struct StatisticsMoodSection: View {
    let moodDistribution: [(Mood, Int)]
    let moodSummaryText: String

    var body: some View {
        Section(String(localized: "Statistics.Section.Moods", defaultValue: "Stimmungen")) {
            NavigationLink {
                MoodStatisticsDetailView(moodDistribution: moodDistribution)
            } label: {
                StatisticNavigationRow(
                    title: String(localized: "Statistics.Moods.Show", defaultValue: "Stimmungen ansehen"),
                    detail: moodSummaryText
                )
            }
        }
    }
}

private struct StatisticsTopRatedPanel: View {
    let topRated: [Episode]

    var body: some View {
        StatisticPanel(
            title: String(localized: "Statistics.Section.TopRated", defaultValue: "Beste Bewertungen"),
            systemImage: "star"
        ) {
            StatisticsTopRatedContent(topRated: topRated)
        }
    }
}

private struct StatisticsMoodPanel: View {
    let moodDistribution: [(Mood, Int)]
    let moodSummaryText: String

    var body: some View {
        StatisticPanel(
            title: String(localized: "Statistics.Section.Moods", defaultValue: "Stimmungen"),
            systemImage: "tag"
        ) {
            NavigationLink {
                MoodStatisticsDetailView(moodDistribution: moodDistribution)
            } label: {
                StatisticNavigationRow(
                    title: String(localized: "Statistics.Moods.Show", defaultValue: "Stimmungen ansehen"),
                    detail: moodSummaryText
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StatisticsTopRatedContent: View {
    let topRated: [Episode]

    var body: some View {
        if topRated.isEmpty {
            EmptyStatisticRow(
                systemImage: "star",
                title: String(localized: "Statistics.TopRated.Empty.Title", defaultValue: "Noch keine Bewertungen"),
                detail: String(
                    localized: "Statistics.TopRated.Empty.Detail",
                    defaultValue: "Bewerte Folgen, um deine Favoriten hier zu sehen."
                )
            )
        } else {
            VStack(spacing: 12) {
                ForEach(topRated) { episode in
                    TopRatedStatisticRow(episode: episode)
                }
            }
        }
    }
}

private struct StatSummaryTile: View {
    let stat: StatisticsOverviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: stat.kind.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(stat.value)
                .font(.title2.weight(.semibold))
            Text(stat.kind.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 120, alignment: .topLeading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatisticPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: 220, alignment: .topLeading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatisticNavigationRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
    }
}

private struct EmptyStatisticRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct TopRatedStatisticRow: View {
    let episode: Episode

    private var metaText: String {
        let universeName = AppLocalization.displayName(forUniverseName: episode.universe?.name)
        return "\(universeName) · Folge \(episode.episodeNumber)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .lineLimit(1)

                Text(metaText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let rating = episode.rating {
                Text("\(rating) ⭐")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MoodStatisticsDetailView: View {
    let moodDistribution: [(Mood, Int)]

    var body: some View {
        List {
            if moodDistribution.isEmpty {
                EmptyStatisticRow(
                    systemImage: "tag",
                    title: String(localized: "Noch keine Stimmungen", defaultValue: "Noch keine Stimmungen"),
                    detail: String(
                        localized: "Ordne Folgen Stimmungen zu, um Muster in deiner Sammlung zu entdecken.",
                        defaultValue: "Ordne Folgen Stimmungen zu, um Muster in deiner Sammlung zu entdecken."
                    )
                )
            } else {
                ForEach(moodDistribution, id: \.0.id) { mood, count in
                    HStack {
                        Text("\(mood.iconName ?? "") \(mood.name)")
                        Spacer()
                        Text("\(count) Folgen")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Statistics.Section.Moods", defaultValue: "Stimmungen"))
    }
}

// MARK: - StatCardGrid

struct StatCardGrid: View {
    let stats: [StatisticsOverviewItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stats) { stat in
                StatCard(stat: stat)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}

private struct StatCard: View {
    let stat: StatisticsOverviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.kind.emoji).font(.title2)
            Text(stat.value).font(.title2.weight(.bold)).monospacedDigit()
            Text(stat.kind.title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
