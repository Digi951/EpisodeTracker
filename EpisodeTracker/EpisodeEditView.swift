import SwiftUI
import SwiftData

struct EpisodeEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Universe.name) private var universes: [Universe]
    @Query(sort: \Episode.episodeNumber) private var allEpisodes: [Episode]
    @Query(sort: \Mood.name) private var allMoods: [Mood]
    @AppStorage(FreemiumAccess.unlockStorageKey) private var isPlusUnlocked = false

    var episode: Episode?
    var prefillEntry: CatalogEntry?
    var prefillUniverseName: String?

    @State private var episodeNumberText: String = ""
    @State private var title: String = ""
    @State private var releaseYearText: String = ""
    @State private var personalNote: String = ""
    @State private var isListened: Bool = false
    @State private var rating: Int?
    @State private var selectedMoods: Set<Mood> = []
    @State private var selectedUniverse: Universe?
    @State private var catalogMatch: CatalogEntry?
    @State private var newMoodName: String = ""
    @State private var newMoodIcon: String = ""
    @State private var formValidationMessage: String?
    @State private var moodValidationMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var pendingCatalogRefreshKey: String?

    private var isNew: Bool { episode == nil }
    private var parsedEpisodeNumber: Int? {
        Int(episodeNumberText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private var parsedReleaseYear: Int? {
        Int(releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private var canCreateEpisodeUnderCurrentPlan: Bool {
        !isNew || FreemiumAccess.canCreateEpisode(
            currentEpisodeCount: allEpisodes.count,
            isPlusUnlocked: isPlusUnlocked
        )
    }
    private var canSave: Bool {
        !title.isEmpty
        && parsedEpisodeNumber != nil
        && parsedReleaseYear != nil
        && selectedUniverse != nil
        && canCreateEpisodeUnderCurrentPlan
    }
    private var suggestedMoods: [(name: String, icon: String)] {
        Mood.defaultSuggestions.filter { suggestion in
            !allMoods.contains { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
        }
    }
    private var preferredCatalogUniverse: Universe? {
        let sourceNames = CatalogSourceRegistry.managedSources.map(\.name)
        if let bundledUniverse = universes.first(where: {
            $0.name.caseInsensitiveCompare(CatalogSourceRegistry.bundledCollectionName) == .orderedSame
        }) {
            return bundledUniverse
        }

        return universes.first { universe in
            sourceNames.contains { $0.caseInsensitiveCompare(universe.name) == .orderedSame }
        }
    }

    var body: some View {
        List {
            Section("Folge") {
                Picker("Katalog", selection: $selectedUniverse) {
                    Text("Katalog auswählen").tag(Optional<Universe>.none)
                    ForEach(universes) { universe in
                        Text(universe.name).tag(Optional(universe))
                    }
                }

                LabeledContent("Nummer") {
                    TextField("Nummer", text: $episodeNumberText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                if let catalogMatch, isNew {
                    Button {
                        title = catalogMatch.title
                        releaseYearText = String(catalogMatch.releaseYear)
                    } label: {
                        Label(
                            "Titel übernehmen: \(catalogMatch.title) (\(String(catalogMatch.releaseYear)))",
                            systemImage: "text.badge.checkmark"
                        )
                        .font(.subheadline)
                    }
                }
                TextField("Titel der Folge", text: $title)
                LabeledContent("Erscheinungsjahr") {
                    TextField("Jahr", text: $releaseYearText)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                if let formValidationMessage {
                    Text(formValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if isNew && !canCreateEpisodeUnderCurrentPlan {
                    Text(FreemiumAccess.limitReachedMessage())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                Toggle("Bereits gehört", isOn: $isListened)
                RatingPicker(rating: $rating)
            }

            Section("Stimmungen") {
                if !suggestedMoods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vorschläge")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(suggestedMoods, id: \.name) { suggestion in
                                    Button {
                                        addSuggestedMood(suggestion)
                                    } label: {
                                        Text("\(suggestion.icon) \(suggestion.name)")
                                            .font(.subheadline)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }

                HStack {
                    TextField("Neue Stimmung", text: $newMoodName)
                    TextField("Symbol", text: $newMoodIcon)
                        .frame(width: 56)
                        .multilineTextAlignment(.center)
                    Button("Hinzufügen") {
                        addMood()
                    }
                    .disabled(newMoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let moodValidationMessage {
                    Text(moodValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                ForEach(allMoods) { mood in
                    let isSelected = selectedMoods.contains(mood)
                    Button {
                        if isSelected {
                            selectedMoods.remove(mood)
                        } else {
                            selectedMoods.insert(mood)
                        }
                    } label: {
                        HStack {
                            Text("\(mood.iconName ?? "") \(mood.name)")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section("Persönliche Notiz") {
                TextField("Was möchtest du dir merken?", text: $personalNote, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(isNew ? "Neue Folge" : "Folge bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    if save() {
                        dismiss()
                    }
                }
                .disabled(!canSave)
            }
            if !isNew {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Folge löschen", systemImage: "trash")
                    }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    dismissKeyboard()
                }
            }
        }
        .confirmationDialog(
            "Folge wirklich löschen?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let episode {
                    modelContext.delete(episode)
                }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .onChange(of: episodeNumberText) {
            let filtered = episodeNumberText.filter(\.isNumber)
            if filtered != episodeNumberText {
                episodeNumberText = filtered
                return
            }

            refreshCatalogMatch()
        }
        .onChange(of: selectedUniverse?.id) {
            refreshCatalogMatch()
        }
        .onChange(of: releaseYearText) {
            let filtered = releaseYearText.filter(\.isNumber)
            if filtered != releaseYearText {
                releaseYearText = filtered
            }
        }
        .onAppear {
            if let episode {
                episodeNumberText = String(episode.episodeNumber)
                title = episode.title
                releaseYearText = String(episode.releaseYear)
                personalNote = episode.personalNote ?? ""
                isListened = episode.isListened
                rating = episode.rating
                selectedMoods = Set(episode.moods)
                selectedUniverse = episode.universe ?? universes.first
            } else if let prefillEntry {
                episodeNumberText = String(prefillEntry.number)
                title = prefillEntry.title
                releaseYearText = String(prefillEntry.releaseYear)
                if let prefillUniverseName {
                    selectedUniverse = universes.first {
                        $0.name.caseInsensitiveCompare(prefillUniverseName) == .orderedSame
                    } ?? universes.first
                } else {
                    selectedUniverse = preferredCatalogUniverse ?? universes.first
                }
            } else if releaseYearText.isEmpty {
                releaseYearText = "1979"
                selectedUniverse = preferredCatalogUniverse ?? universes.first
            }
            refreshCatalogMatch()
        }
    }

    private func save() -> Bool {
        guard let episodeNumber = parsedEpisodeNumber else { return false }
        guard let releaseYear = parsedReleaseYear else { return false }
        guard let selectedUniverse else { return false }

        formValidationMessage = nil
        guard canCreateEpisodeUnderCurrentPlan else {
            formValidationMessage = FreemiumAccess.limitReachedMessage()
            return false
        }

        if hasDuplicateEpisodeNumber(in: selectedUniverse, episodeNumber: episodeNumber) {
            formValidationMessage = "Diese Folgennummer ist in diesem Katalog schon vorhanden."
            return false
        }

        if let episode {
            let wasListened = episode.isListened
            episode.episodeNumber = episodeNumber
            episode.title = title
            episode.releaseYear = releaseYear
            episode.personalNote = personalNote.isEmpty ? nil : personalNote
            episode.isListened = isListened
            episode.rating = rating
            episode.universe = selectedUniverse
            episode.moods = Array(selectedMoods)

            if isListened && !wasListened {
                episode.listenCount += 1
                episode.lastListenedAt = .now
            }
        } else {
            let newEpisode = Episode(
                episodeNumber: episodeNumber,
                title: title,
                releaseYear: releaseYear,
                personalNote: personalNote.isEmpty ? nil : personalNote,
                isListened: isListened,
                rating: rating,
                universe: selectedUniverse,
                moods: Array(selectedMoods)
            )
            if isListened {
                newEpisode.listenCount = 1
                newEpisode.lastListenedAt = .now
            }
            modelContext.insert(newEpisode)
        }
        return true
    }

    private func hasDuplicateEpisodeNumber(in universe: Universe, episodeNumber: Int) -> Bool {
        allEpisodes.contains { existingEpisode in
            guard existingEpisode.episodeNumber == episodeNumber else { return false }
            guard existingEpisode.universe?.id == universe.id else { return false }
            if let episode {
                return existingEpisode.id != episode.id
            }
            return true
        }
    }

    private func refreshCatalogMatch() {
        guard isNew, let number = parsedEpisodeNumber else {
            catalogMatch = nil
            return
        }

        let universeName = selectedUniverse?.name
        catalogMatch = EpisodeCatalog.shared.entry(for: number, in: universeName)

        if catalogMatch == nil {
            refreshCatalogForSuggestionIfNeeded(number: number, universeName: universeName)
        }
    }

    private func refreshCatalogForSuggestionIfNeeded(number: Int, universeName: String?) {
        guard let universeName, !universeName.isEmpty else { return }
        let refreshKey = "\(universeName)#\(number)"
        guard pendingCatalogRefreshKey != refreshKey else { return }
        pendingCatalogRefreshKey = refreshKey

        Task { @MainActor in
            await EpisodeCatalog.shared.refreshManagedCatalog(universeName: universeName, force: false)
            if pendingCatalogRefreshKey == refreshKey {
                catalogMatch = EpisodeCatalog.shared.entry(for: number, in: universeName)
                pendingCatalogRefreshKey = nil
            }
        }
    }

    private func addSuggestedMood(_ suggestion: (name: String, icon: String)) {
        if let existingMood = allMoods.first(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
            selectedMoods.insert(existingMood)
            return
        }

        let mood = Mood(name: suggestion.name, iconName: suggestion.icon)
        modelContext.insert(mood)
        selectedMoods.insert(mood)
    }

    private func addMood() {
        moodValidationMessage = nil

        let trimmedName = newMoodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            moodValidationMessage = "Bitte gib einen Namen ein."
            return
        }

        if let existingMood = allMoods.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            selectedMoods.insert(existingMood)
            moodValidationMessage = "Diese Stimmung gibt es schon. Ich habe sie ausgewählt."
            return
        }

        let trimmedIcon = newMoodIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        let mood = Mood(
            name: trimmedName,
            iconName: trimmedIcon.isEmpty ? nil : String(trimmedIcon.prefix(2))
        )
        modelContext.insert(mood)
        selectedMoods.insert(mood)
        newMoodName = ""
        newMoodIcon = ""
    }
}

struct RatingPicker: View {
    @Binding var rating: Int?

    var body: some View {
        HStack {
            Text("Bewertung")
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        if rating == star {
                            rating = nil
                        } else {
                            rating = star
                        }
                    } label: {
                        Image(systemName: star <= (rating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(star <= (rating ?? 0) ? .yellow : .gray.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
