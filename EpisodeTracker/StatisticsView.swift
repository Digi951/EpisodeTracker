import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var episodes: [Episode]

    private var summaryColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
        ]
    }

    private var detailColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16),
            GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16)
        ]
    }

    private var listenedCount: Int {
        episodes.filter(\.isListened).count
    }

    private var unlistenedCount: Int {
        episodes.count - listenedCount
    }

    private var averageRating: Double? {
        let rated = episodes.compactMap(\.rating)
        guard !rated.isEmpty else { return nil }
        return Double(rated.reduce(0, +)) / Double(rated.count)
    }

    private var totalListens: Int {
        episodes.reduce(0) { $0 + $1.listenCount }
    }

    private var topRated: [Episode] {
        episodes
            .filter { $0.rating != nil }
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    private var moodDistribution: [(Mood, Int)] {
        var counts: [Mood: Int] = [:]
        for episode in episodes {
            for mood in episode.moods {
                counts[mood, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }

    private var overviewStats: [StatSummary] {
        var stats = [
            StatSummary(title: "Folgen", value: "\(episodes.count)", systemImage: "list.number"),
            StatSummary(title: "Gehört", value: "\(listenedCount)", systemImage: "checkmark.circle"),
            StatSummary(title: "Offen", value: "\(unlistenedCount)", systemImage: "circle"),
            StatSummary(title: "Hördurchgänge", value: "\(totalListens)", systemImage: "ear")
        ]

        if let avg = averageRating {
            stats.append(
                StatSummary(
                    title: "Schnitt",
                    value: String(format: "%.1f ⭐", avg),
                    systemImage: "star"
                )
            )
        }

        return stats
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .navigationTitle("Statistiken")
    }

    private var iPhoneBody: some View {
        List {
            if episodes.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Statistik", systemImage: "chart.bar")
                } description: {
                    Text("Sobald du Folgen anlegst, siehst du hier deinen Hörstand.")
                }
            } else {
                Section("Übersicht") {
                    ForEach(overviewStats) { stat in
                        StatRow(label: stat.title, value: stat.value)
                    }
                }

                Section("Beste Bewertungen") {
                    if topRated.isEmpty {
                        EmptyStatisticRow(
                            systemImage: "star",
                            title: "Noch keine Bewertungen",
                            detail: "Bewerte Folgen, um deine Favoriten hier zu sehen."
                        )
                    } else {
                        ForEach(topRated) { episode in
                            HStack {
                                Text("\(episode.episodeNumber). \(episode.title)")
                                    .lineLimit(1)
                                Spacer()
                                if let rating = episode.rating {
                                    Text("\(rating) ⭐")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Stimmungen") {
                    if moodDistribution.isEmpty {
                        EmptyStatisticRow(
                            systemImage: "tag",
                            title: "Noch keine Stimmungen",
                            detail: "Ordne Folgen Stimmungen zu, um Muster in deiner Sammlung zu entdecken."
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
            }
        }
    }

    private var iPadBody: some View {
        ScrollView {
            if episodes.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Statistik", systemImage: "chart.bar")
                } description: {
                    Text("Sobald du Folgen anlegst, siehst du hier deinen Hörstand.")
                }
                .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dein Hörstand auf einen Blick")
                            .font(.title3.weight(.semibold))
                        Text("Die wichtigsten Zahlen und Muster deiner Sammlung, optimiert für einen schnellen Überblick.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(
                        columns: summaryColumns,
                        spacing: 16
                    ) {
                        ForEach(overviewStats) { stat in
                            StatSummaryTile(stat: stat)
                        }
                    }

                    LazyVGrid(
                        columns: detailColumns,
                        alignment: .leading,
                        spacing: 16
                    ) {
                        StatisticPanel(title: "Beste Bewertungen", systemImage: "star") {
                            if topRated.isEmpty {
                                EmptyStatisticRow(
                                    systemImage: "star",
                                    title: "Noch keine Bewertungen",
                                    detail: "Bewerte Folgen, um deine Favoriten hier zu sehen."
                                )
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(topRated) { episode in
                                        HStack {
                                            Text("\(episode.episodeNumber). \(episode.title)")
                                                .lineLimit(1)
                                            Spacer()
                                            if let rating = episode.rating {
                                                Text("\(rating) ⭐")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        StatisticPanel(title: "Stimmungen", systemImage: "tag") {
                            if moodDistribution.isEmpty {
                                EmptyStatisticRow(
                                    systemImage: "tag",
                                    title: "Noch keine Stimmungen",
                                    detail: "Ordne Folgen Stimmungen zu, um Muster in deiner Sammlung zu entdecken."
                                )
                            } else {
                                VStack(spacing: 12) {
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
                        }
                    }
                }
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct StatSummary: Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { title }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
    }
}

private struct StatSummaryTile: View {
    let stat: StatSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: stat.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(stat.value)
                .font(.title2.weight(.semibold))
            Text(stat.title)
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
