import SwiftUI
import SwiftData

struct MoodManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mood.name) private var moods: [Mood]

    @State private var newMoodName: String = ""
    @State private var newMoodIcon: String = ""
    @State private var validationMessage: String?

    private var suggestedMoods: [(name: String, icon: String)] {
        Mood.defaultSuggestions.filter { suggestion in
            !moods.contains { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
        }
    }

    var body: some View {
        List {
            Section("Neue Stimmung") {
                HStack {
                    TextField("Name", text: $newMoodName)
                    TextField("Symbol", text: $newMoodIcon)
                        .frame(width: 56)
                        .multilineTextAlignment(.center)
                    Button("Hinzufügen") {
                        addMood(name: newMoodName, icon: newMoodIcon)
                    }
                    .disabled(newMoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if !suggestedMoods.isEmpty {
                Section("Standard-Vorschläge") {
                    ForEach(suggestedMoods, id: \.name) { suggestion in
                        Button {
                            addMood(name: suggestion.name, icon: suggestion.icon)
                        } label: {
                            HStack {
                                Text("\(suggestion.icon) \(suggestion.name)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section {
                if moods.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Noch keine Stimmungen", defaultValue: "Noch keine Stimmungen"), systemImage: "tag")
                    } description: {
                        Text(
                            String(
                                localized: "Lege eigene Stimmungen an oder übernimm Standard-Vorschläge.",
                                defaultValue: "Lege eigene Stimmungen an oder übernimm Standard-Vorschläge."
                            )
                        )
                    }
                } else {
                    ForEach(moods) { mood in
                        HStack {
                            Text("\(mood.iconName ?? "") \(mood.name)")
                            Spacer()
                            if !mood.episodes.isEmpty {
                                Text("\(mood.episodes.count) Folgen")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteMoods)
                }
            } header: {
                Text(String(localized: "Vorhandene Stimmungen", defaultValue: "Vorhandene Stimmungen"))
            } footer: {
                Text(String(localized: "Nur ungenutzte Stimmungen können gelöscht werden.", defaultValue: "Nur ungenutzte Stimmungen können gelöscht werden."))
            }
        }
        .navigationTitle(String(localized: "Statistics.Section.Moods", defaultValue: "Stimmungen"))
    }

    private func addMood(name: String, icon: String) {
        validationMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen ein."
            return
        }

        if moods.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            validationMessage = "Diese Stimmung existiert bereits."
            return
        }

        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let mood = Mood(
            name: trimmedName,
            iconName: trimmedIcon.isEmpty ? nil : String(trimmedIcon.prefix(2))
        )
        modelContext.insert(mood)

        newMoodName = ""
        newMoodIcon = ""
    }

    private func deleteMoods(at offsets: IndexSet) {
        validationMessage = nil

        for index in offsets {
            let mood = moods[index]
            if mood.episodes.isEmpty {
                modelContext.delete(mood)
            } else {
                validationMessage = String(
                    localized: "Nur ungenutzte Stimmungen können gelöscht werden.",
                    defaultValue: "Nur ungenutzte Stimmungen können gelöscht werden."
                )
            }
        }
    }
}
