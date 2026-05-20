import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var yearSuggestions: [CatalogEntry] = []
    @State private var newMoodName: String = ""
    @State private var newMoodIcon: String = ""
    @State private var formValidationMessage: String?
    @State private var moodValidationMessage: String?
    @State private var streamingURL: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var pendingCatalogRefreshKey: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var removeCover = false
    @State private var clipboardHasImage = false
    @Environment(\.scenePhase) private var scenePhase

    private var isNew: Bool { episode == nil }
    private var hasVisibleCover: Bool {
        if removeCover { return false }
        return coverImage != nil || (episode?.coverImageName != nil && !(episode?.coverImageName?.isEmpty ?? true))
    }
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
    private var activeUniverses: [Universe] {
        let activeIDs = ActiveCatalogStore().activeIDs
        let activeManagedNames = Set(
            CatalogSourceRegistry.managedSources
                .filter { activeIDs.contains($0.id) }
                .map { $0.name.lowercased() }
        )
        return universes.filter { universe in
            let key = universe.name.lowercased()
            let isManagedSource = CatalogSourceRegistry.managedSources.contains {
                $0.name.lowercased() == key
            }
            if isManagedSource {
                return activeManagedNames.contains(key)
            }
            return true // custom universes always shown
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
            EpisodeFormSection(
                universes: activeUniverses,
                selectedUniverse: $selectedUniverse,
                episodeNumberText: $episodeNumberText,
                title: $title,
                releaseYearText: $releaseYearText,
                catalogMatch: catalogMatch,
                isNew: isNew,
                yearSuggestions: yearSuggestions,
                formValidationMessage: formValidationMessage,
                canCreateEpisodeUnderCurrentPlan: canCreateEpisodeUnderCurrentPlan,
                onApplyCatalogMatch: applyCatalogMatch,
                onSelectSuggestedEntry: applySuggestedEntry
            )

            Section {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(maxWidth: .infinity)
                } else if !removeCover, let existingName = episode?.coverImageName, !existingName.isEmpty {
                    CoverImageView(name: existingName, maxHeight: 200)
                        .frame(maxWidth: .infinity)
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images
                ) {
                    Label(
                        hasVisibleCover ? "Cover ersetzen" : "Cover hinzufügen",
                        systemImage: hasVisibleCover ? "photo.badge.arrow.down" : "photo.badge.plus"
                    )
                }

                Button {
                    if let image = UIPasteboard.general.image {
                        coverImage = image
                        selectedPhotoItem = nil
                        removeCover = false
                    }
                } label: {
                    Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                        .foregroundStyle(clipboardHasImage ? Color.accentColor : Color(.tertiaryLabel))
                }
                .disabled(!clipboardHasImage)

                if hasVisibleCover {
                    Button(role: .destructive) {
                        coverImage = nil
                        selectedPhotoItem = nil
                        removeCover = true
                    } label: {
                        Label("Cover entfernen", systemImage: "trash")
                    }
                }
            } header: {
                Text("Cover")
            }

            EpisodeStatusSection(
                isListened: $isListened,
                rating: $rating
            )

            EpisodeMoodSection(
                suggestedMoods: suggestedMoods,
                newMoodName: $newMoodName,
                newMoodIcon: $newMoodIcon,
                moodValidationMessage: moodValidationMessage,
                allMoods: allMoods,
                selectedMoods: selectedMoods,
                onAddSuggestedMood: addSuggestedMood,
                onAddMood: addMood,
                onToggleMood: toggleMoodSelection
            )

            EpisodeNoteSection(personalNote: $personalNote)

            EpisodeStreamingSection(streamingURL: $streamingURL)
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
                    EpisodeDeleteHelper.delete(episode, from: modelContext)
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
            refreshYearSuggestions()
        }
        .onChange(of: selectedUniverse?.name) {
            refreshYearSuggestions()
        }
        .onAppear {
            populateInitialState()
            refreshCatalogMatch()
            clipboardHasImage = UIPasteboard.general.hasImages
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                clipboardHasImage = UIPasteboard.general.hasImages
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    coverImage = uiImage
                    removeCover = false
                }
            }
        }
    }

    private func populateInitialState() {
        if let episode {
            episodeNumberText = String(episode.episodeNumber)
            title = episode.title
            releaseYearText = String(episode.releaseYear)
            personalNote = episode.personalNote ?? ""
            isListened = episode.isListened
            rating = episode.rating
            streamingURL = episode.streamingURL ?? ""
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
            episode.streamingURL = streamingURL.isEmpty ? nil : streamingURL
            episode.refreshSyncKeyIfPossible()
            applyCoverChange(to: episode)

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
            newEpisode.streamingURL = streamingURL.isEmpty ? nil : streamingURL
            if isListened {
                newEpisode.listenCount = 1
                newEpisode.lastListenedAt = .now
            }
            applyCoverChange(to: newEpisode)
            modelContext.insert(newEpisode)
        }

        do {
            try modelContext.save()
            return true
        } catch {
            formValidationMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
            return false
        }
    }

    private func applyCoverChange(to episode: Episode) {
        let change: EpisodeCoverChange
        if removeCover {
            change = .remove
        } else if let coverImage {
            change = .replace(coverImage)
        } else {
            change = .keep
        }

        try? EpisodeCoverManager().apply(change, to: episode)
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

    private func refreshYearSuggestions() {
        guard isNew,
              let year = parsedReleaseYear, year > 1900,
              let universeName = selectedUniverse?.name, !universeName.isEmpty
        else {
            yearSuggestions = []
            return
        }

        let key = universeName.lowercased()
        let libraryNumbers = Set(allEpisodes.filter {
            $0.universe?.name.lowercased() == key
        }.map(\.episodeNumber))

        var seenNumbers = Set<Int>()
        yearSuggestions = EpisodeCatalog.shared.allEntries
            .filter {
                $0.releaseYear == year
                && $0.collectionName?.lowercased() == key
                && !libraryNumbers.contains($0.number)
            }
            .sorted { $0.number < $1.number }
            .filter { seenNumbers.insert($0.number).inserted }
    }

    private func addSuggestedMood(_ suggestion: (name: String, icon: String)) {
        if let existingMood = allMoods.first(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
            selectedMoods.insert(existingMood)
            return
        }

        let mood = Mood(name: suggestion.name, iconName: suggestion.icon)
        modelContext.insert(mood)
        selectedMoods.insert(mood)
        try? modelContext.save()
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
        try? modelContext.save()
        newMoodName = ""
        newMoodIcon = ""
    }

    private func applyCatalogMatch() {
        guard let catalogMatch else { return }
        title = catalogMatch.title
        releaseYearText = String(catalogMatch.releaseYear)
    }

    private func applySuggestedEntry(_ entry: CatalogEntry) {
        episodeNumberText = String(entry.number)
        title = entry.title
        releaseYearText = String(entry.releaseYear)
    }

    private func toggleMoodSelection(_ mood: Mood) {
        if selectedMoods.contains(mood) {
            selectedMoods.remove(mood)
        } else {
            selectedMoods.insert(mood)
        }
    }
}

private struct EpisodeFormSection: View {
    let universes: [Universe]
    @Binding var selectedUniverse: Universe?
    @Binding var episodeNumberText: String
    @Binding var title: String
    @Binding var releaseYearText: String
    let catalogMatch: CatalogEntry?
    let isNew: Bool
    let yearSuggestions: [CatalogEntry]
    let formValidationMessage: String?
    let canCreateEpisodeUnderCurrentPlan: Bool
    let onApplyCatalogMatch: () -> Void
    let onSelectSuggestedEntry: (CatalogEntry) -> Void

    var body: some View {
        Section("Folge") {
            Picker("Katalog", selection: $selectedUniverse) {
                if selectedUniverse == nil {
                    Text("Katalog auswählen").tag(Optional<Universe>.none)
                }
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
                Button(action: onApplyCatalogMatch) {
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
            if isNew && !yearSuggestions.isEmpty && episodeNumberText.isEmpty {
                DisclosureGroup("Folgen aus \(releaseYearText)") {
                    ForEach(Array(yearSuggestions.enumerated()), id: \.offset) { _, entry in
                        Button {
                            onSelectSuggestedEntry(entry)
                        } label: {
                            HStack {
                                Text("\(entry.number)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                                Text(entry.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .font(.subheadline)
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
    }
}

private struct EpisodeStatusSection: View {
    @Binding var isListened: Bool
    @Binding var rating: Int?

    var body: some View {
        Section("Status") {
            Toggle("Bereits gehört", isOn: $isListened)
            RatingPicker(rating: $rating)
        }
    }
}

private struct EpisodeMoodSection: View {
    let suggestedMoods: [(name: String, icon: String)]
    @Binding var newMoodName: String
    @Binding var newMoodIcon: String
    let moodValidationMessage: String?
    let allMoods: [Mood]
    let selectedMoods: Set<Mood>
    let onAddSuggestedMood: ((name: String, icon: String)) -> Void
    let onAddMood: () -> Void
    let onToggleMood: (Mood) -> Void

    var body: some View {
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
                                    onAddSuggestedMood(suggestion)
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
                Button("Hinzufügen", action: onAddMood)
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
                    onToggleMood(mood)
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
    }
}

private struct EpisodeNoteSection: View {
    @Binding var personalNote: String

    var body: some View {
        Section("Persönliche Notiz") {
            TextField("Was möchtest du dir merken?", text: $personalNote, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

private struct EpisodeStreamingSection: View {
    @Binding var streamingURL: String

    var body: some View {
        Section {
            TextField("https://open.spotify.com/album/...", text: $streamingURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Streaming-Link")
        } footer: {
            Text("Direktlink zu Spotify oder Apple Music. Wird in der Folgendetailansicht als Button angezeigt.")
        }
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
