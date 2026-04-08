import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query private var episodes: [Episode]

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

    var body: some View {
        List {
            Section("Übersicht") {
                StatRow(label: "Folgen gesamt", value: "\(episodes.count)")
                StatRow(label: "Gehört", value: "\(listenedCount)")
                StatRow(label: "Nicht gehört", value: "\(unlistenedCount)")
                StatRow(label: "Gesamte Hördurchgänge", value: "\(totalListens)")
                if let avg = averageRating {
                    StatRow(label: "Durchschnittliche Bewertung", value: String(format: "%.1f ⭐", avg))
                }
            }

            if !topRated.isEmpty {
                Section("Top-bewertete Folgen") {
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

            if !moodDistribution.isEmpty {
                Section("Stimmungen") {
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
        .navigationTitle("Statistiken")
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
    }
}
