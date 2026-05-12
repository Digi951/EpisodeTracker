import SwiftUI
import SwiftData

struct MoodPickerView: View {
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var allMoods: [Mood]

    private var moodsWithCounts: [(mood: Mood, count: Int)] {
        SmartListDefinition.availableMoods(from: episodes, filter: .all, allMoods: allMoods)
    }

    var body: some View {
        List {
            if moodsWithCounts.isEmpty {
                ContentUnavailableView {
                    Label("Keine Stimmungen", systemImage: "tray")
                } description: {
                    Text("Noch keine Stimmungen in deiner Bibliothek")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(moodsWithCounts, id: \.mood.id) { item in
                    NavigationLink(value: SmartListNavigation.moodDetail(item.mood)) {
                        HStack(spacing: 12) {
                            Text(item.mood.iconName ?? "🎵")
                                .font(.title2)
                                .frame(width: 32)

                            Text(item.mood.name)
                                .font(.body)

                            Spacer()

                            Text("\(item.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Stimmung wählen")
    }
}
