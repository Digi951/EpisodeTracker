import SwiftUI

struct UpcomingReleasesSheet: View {
    let feed: UpcomingReleasesFeed

    @Environment(\.dismiss) private var dismiss

    private var rowsByDate: [(date: Date, rows: [UpcomingReleasesFeed.Row])] {
        Dictionary(grouping: feed.rows) { Calendar.current.startOfDay(for: $0.release.releaseDate) }
            .map { (date: $0.key, rows: $0.value) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if feed.rows.isEmpty {
                    ContentUnavailableView(
                        "Keine Termine",
                        systemImage: "calendar",
                        description: Text("Zurzeit sind für deine aktivierten Kataloge keine neuen Folgen angekündigt.")
                    )
                } else {
                    ForEach(rowsByDate, id: \.date) { group in
                        Section {
                            ForEach(group.rows) { row in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.release.number.map { "\(row.seriesName) · Folge \($0)" } ?? row.seriesName)
                                    Text(row.release.title)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text(group.date.formatted(date: .long, time: .omitted))
                        }
                    }
                }

                Section {
                    Label(
                        "Nur Kataloge mit offiziell angekündigtem Termin. Für andere aktivierte Kataloge liegt kein verlässliches Datum vor.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                }
            }
            .navigationTitle("Bald verfügbar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
