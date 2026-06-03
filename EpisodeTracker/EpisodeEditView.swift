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
    @AppStorage("episodeEditCoverSectionCollapsed") private var isCoverSectionCollapsed = false
    @AppStorage("episodeEditStatusSectionCollapsed") private var isStatusSectionCollapsed = false
    @AppStorage("episodeEditMoodSectionCollapsed") private var isMoodSectionCollapsed = false
    @AppStorage("episodeEditNoteSectionCollapsed") private var isNoteSectionCollapsed = false
    @AppStorage("episodeEditStreamingSectionCollapsed") private var isStreamingSectionCollapsed = false

    var episode: Episode?
    var prefillEntry: CatalogEntry?
    var prefillUniverseName: String?

    @State private var draft = EpisodeEditDraft()
    @State private var coverHandler = EpisodeEditCoverHandler()
    @State private var catalogMatch: CatalogEntry?
    @State private var yearSuggestions: [CatalogEntry] = []
    @State private var newMoodName: String = ""
    @State private var newMoodIcon: String = ""
    @State private var formValidationMessage: String?
    @State private var moodValidationMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var pendingCatalogRefreshKey: String?
    @Environment(\.scenePhase) private var scenePhase

    private var isNew: Bool { episode == nil }
    private var hasVisibleCover: Bool {
        coverHandler.hasVisibleCover(for: episode)
    }
    private var canCreateEpisodeUnderCurrentPlan: Bool {
        !isNew || FreemiumAccess.canCreateEpisode(
            currentEpisodeCount: allEpisodes.count,
            isPlusUnlocked: isPlusUnlocked
        )
    }
    private var canSave: Bool {
        draft.isComplete && canCreateEpisodeUnderCurrentPlan
    }
    private var duplicateEpisodeWarning: String? {
        guard isNew,
              !draft.isSpecial,
              let number = draft.parsedEpisodeNumber,
              let universe = draft.selectedUniverse,
              hasDuplicateEpisodeNumber(in: universe, episodeNumber: number)
        else { return nil }
        return "Folge \(number) existiert bereits in \(universe.name)."
    }

    private var suggestedMoods: [(name: String, icon: String)] {
        Mood.defaultSuggestions.filter { suggestion in
            !allMoods.contains { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
        }
    }
    private var visibleMoods: [Mood] {
        Dictionary(grouping: allMoods) { $0.normalizedName }
            .values
            .compactMap { duplicates in
                duplicates.sorted { lhs, rhs in
                    if lhs.episodes.count != rhs.episodes.count {
                        return lhs.episodes.count > rhs.episodes.count
                    }

                    let lhsHasIcon = lhs.iconName?.isEmpty == false
                    let rhsHasIcon = rhs.iconName?.isEmpty == false
                    if lhsHasIcon != rhsHasIcon {
                        return lhsHasIcon
                    }

                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                .first
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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

    private var titleSuggestions: [CatalogEntry] {
        guard isNew else { return [] }
        let activeCollectionNames = activeCatalogCollectionNames
        return CatalogTitleAutocomplete.suggestions(
            for: draft.title,
            entries: EpisodeCatalog.shared.allEntries,
            activeCollectionNames: activeCollectionNames,
            selectedCollectionName: draft.selectedUniverse?.name,
            existingEpisodeNumbersByCollection: existingEpisodeNumbersByCollection
        )
    }

    private var activeCatalogCollectionNames: Set<String> {
        let activeIDs = ActiveCatalogStore().activeIDs
        return Set(
            EpisodeCatalog.shared.managedSources
                .filter { activeIDs.contains($0.id) }
                .map { CatalogLibraryMatcher.normalizedCollectionKey($0.name) }
        )
    }

    private var existingEpisodeNumbersByCollection: [String: Set<Int>] {
        CatalogLibraryMatcher.existingNumbersByCollection(libraryEpisodes: allEpisodes)
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
                selectedUniverse: $draft.selectedUniverse,
                isSpecial: $draft.isSpecial,
                episodeNumberText: $draft.episodeNumberText,
                title: $draft.title,
                releaseYearText: $draft.releaseYearText,
                catalogMatch: catalogMatch,
                isNew: isNew,
                yearSuggestions: yearSuggestions,
                titleSuggestions: titleSuggestions,
                formValidationMessage: formValidationMessage,
                duplicateEpisodeWarning: duplicateEpisodeWarning,
                canCreateEpisodeUnderCurrentPlan: canCreateEpisodeUnderCurrentPlan,
                onApplyCatalogMatch: applyCatalogMatch,
                onSelectSuggestedEntry: applySuggestedEntry
            )

            CollapsibleEpisodeSection("Cover", isCollapsed: $isCoverSectionCollapsed) {
                if let coverImage = coverHandler.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(maxWidth: .infinity)
                } else if !coverHandler.removeCover, let existingName = episode?.coverImageName, !existingName.isEmpty {
                    CoverImageView(name: existingName, maxHeight: 200)
                        .frame(maxWidth: .infinity)
                }

                PhotosPicker(
                    selection: $coverHandler.selectedPhotoItem,
                    matching: .images
                ) {
                    Label(
                        hasVisibleCover ? "Cover ersetzen" : "Cover hinzufügen",
                        systemImage: hasVisibleCover ? "photo.badge.arrow.down" : "photo.badge.plus"
                    )
                }

                Button {
                    coverHandler.pasteFromClipboard()
                } label: {
                    Label("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard")
                        .foregroundStyle(
                            coverHandler.clipboardHasImage
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(Color(.tertiaryLabel))
                        )
                }
                .disabled(!coverHandler.clipboardHasImage)

                if hasVisibleCover {
                    Button(role: .destructive) {
                        coverHandler.requestRemoval()
                    } label: {
                        Label("Cover entfernen", systemImage: "trash")
                    }
                }
            }

            EpisodeStatusSection(
                isCollapsed: $isStatusSectionCollapsed,
                isListened: $draft.isListened,
                rating: $draft.rating
            )

            EpisodeMoodSection(
                isCollapsed: $isMoodSectionCollapsed,
                suggestedMoods: suggestedMoods,
                newMoodName: $newMoodName,
                newMoodIcon: $newMoodIcon,
                moodValidationMessage: moodValidationMessage,
                allMoods: visibleMoods,
                selectedMoods: draft.selectedMoods,
                onAddSuggestedMood: addSuggestedMood,
                onAddMood: addMood,
                onToggleMood: toggleMoodSelection
            )

            EpisodeNoteSection(
                isCollapsed: $isNoteSectionCollapsed,
                personalNote: $draft.personalNote
            )

            EpisodeStreamingSection(
                isCollapsed: $isStreamingSectionCollapsed,
                streamingURL: $draft.streamingURL
            )

            if !isNew {
                Section {
                    Toggle("Ausgeblendet", isOn: $draft.isHidden)
                } footer: {
                    Text("Ausgeblendete Folgen erscheinen nicht in Smart Lists und Vorschlägen.")
                }
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
                    guard canCreateEpisodeUnderCurrentPlan else {
                        formValidationMessage = FreemiumAccess.limitReachedMessage()
                        return
                    }
                    formValidationMessage = nil
                    let outcome = EpisodeEditSaveHandler.save(
                        draft: draft,
                        existingEpisode: episode,
                        existingEpisodes: allEpisodes,
                        coverChange: coverHandler.coverChange,
                        in: modelContext
                    )
                    switch outcome {
                    case .saved:
                        dismiss()
                    case .duplicateNumber:
                        formValidationMessage = "Diese Folgennummer ist in diesem Katalog schon vorhanden."
                    case .saveFailed:
                        formValidationMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
                    case .invalidInput:
                        break
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
        .onChange(of: draft.episodeNumberText) {
            let filtered = draft.episodeNumberText.filter(\.isNumber)
            if filtered != draft.episodeNumberText {
                draft.episodeNumberText = filtered
                return
            }

            refreshCatalogMatch()
        }
        .onChange(of: draft.selectedUniverse?.id) {
            refreshCatalogMatch()
        }
        .onChange(of: draft.releaseYearText) {
            let filtered = draft.releaseYearText.filter(\.isNumber)
            if filtered != draft.releaseYearText {
                draft.releaseYearText = filtered
            }
            refreshYearSuggestions()
        }
        .onChange(of: draft.selectedUniverse?.name) {
            refreshYearSuggestions()
        }
        .onAppear {
            SyncPreparation.prepare(context: modelContext)
            populateInitialState()
            refreshCatalogMatch()
            coverHandler.refreshClipboardAvailability()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                coverHandler.refreshClipboardAvailability()
            }
        }
        .onChange(of: coverHandler.selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await coverHandler.loadPickedItem(newItem) }
        }
    }

    private func populateInitialState() {
        if let episode {
            draft = EpisodeEditDraft(episode: episode, universes: universes)
        } else if let prefillEntry {
            draft.episodeNumberText = prefillEntry.number.map(String.init) ?? ""
            draft.title = prefillEntry.title
            draft.releaseYearText = String(prefillEntry.releaseYear)
            if let prefillUniverseName {
                draft.selectedUniverse = universes.first {
                    $0.name.caseInsensitiveCompare(prefillUniverseName) == .orderedSame
                } ?? universes.first
            } else {
                draft.selectedUniverse = preferredCatalogUniverse ?? universes.first
            }
        } else if draft.releaseYearText.isEmpty {
            draft.releaseYearText = "1979"
            draft.selectedUniverse = preferredCatalogUniverse ?? universes.first
        }
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
        guard isNew, let number = draft.parsedEpisodeNumber else {
            catalogMatch = nil
            return
        }

        let universeName = draft.selectedUniverse?.name
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
              let year = draft.parsedReleaseYear, year > 1900,
              let universeName = draft.selectedUniverse?.name, !universeName.isEmpty
        else {
            yearSuggestions = []
            return
        }

        let key = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
        let libraryNumbers = existingEpisodeNumbersByCollection[key] ?? []

        var seenNumbers = Set<Int>()
        yearSuggestions = EpisodeCatalog.shared.allEntries
            .filter { entry in
                guard let number = entry.number else { return false }
                return entry.releaseYear == year
                && CatalogLibraryMatcher.normalizedCollectionKey(entry.collectionName ?? "") == key
                && !libraryNumbers.contains(number)
            }
            .sorted { ($0.number ?? 0) < ($1.number ?? 0) }
            .filter { entry in
                guard let number = entry.number else { return false }
                return seenNumbers.insert(number).inserted
            }
    }

    private func addSuggestedMood(_ suggestion: (name: String, icon: String)) {
        if let existingMood = allMoods.first(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
            draft.selectedMoods.insert(existingMood)
            return
        }

        let mood = Mood(name: suggestion.name, iconName: suggestion.icon)
        modelContext.insert(mood)
        draft.selectedMoods.insert(mood)
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
            draft.selectedMoods.insert(existingMood)
            moodValidationMessage = "Diese Stimmung gibt es schon. Ich habe sie ausgewählt."
            return
        }

        let trimmedIcon = newMoodIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        let mood = Mood(
            name: trimmedName,
            iconName: trimmedIcon.isEmpty ? nil : String(trimmedIcon.prefix(2))
        )
        modelContext.insert(mood)
        draft.selectedMoods.insert(mood)
        try? modelContext.save()
        newMoodName = ""
        newMoodIcon = ""
    }

    private func applyCatalogMatch() {
        guard let catalogMatch else { return }
        draft.title = catalogMatch.title
        draft.releaseYearText = String(catalogMatch.releaseYear)
    }

    private func applySuggestedEntry(_ entry: CatalogEntry) {
        draft.episodeNumberText = entry.number.map(String.init) ?? ""
        draft.title = entry.title
        draft.releaseYearText = String(entry.releaseYear)
    }

    private func toggleMoodSelection(_ mood: Mood) {
        if draft.selectedMoods.contains(mood) {
            draft.selectedMoods.remove(mood)
        } else {
            draft.selectedMoods.insert(mood)
        }
    }
}

private struct CollapsibleEpisodeSection<Content: View>: View {
    let title: String
    @Binding var isCollapsed: Bool
    @ViewBuilder let content: Content

    init(
        _ title: String,
        isCollapsed: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _isCollapsed = isCollapsed
        self.content = content()
    }

    var body: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    AnimatedDisclosureChevron(isCollapsed: isCollapsed)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isCollapsed)
    }
}

private struct AnimatedDisclosureChevron: View {
    let isCollapsed: Bool
    @State private var rotation = 0.0

    private var targetRotation: Double {
        isCollapsed ? 0 : 90
    }

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 18, height: 18)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = targetRotation
            }
            .onChange(of: isCollapsed) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    rotation = targetRotation
                }
            }
    }
}

private struct EpisodeFormSection: View {
    let universes: [Universe]
    @Binding var selectedUniverse: Universe?
    @Binding var isSpecial: Bool
    @Binding var episodeNumberText: String
    @Binding var title: String
    @Binding var releaseYearText: String
    let catalogMatch: CatalogEntry?
    let isNew: Bool
    let yearSuggestions: [CatalogEntry]
    let titleSuggestions: [CatalogEntry]
    let formValidationMessage: String?
    let duplicateEpisodeWarning: String?
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

            Toggle("Sonderfolge", isOn: $isSpecial)

            LabeledContent(isSpecial ? "Nummer (optional)" : "Nummer") {
                TextField(isSpecial ? "Nummer (optional)" : "Nummer", text: $episodeNumberText)
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
            if isNew && !titleSuggestions.isEmpty {
                DisclosureGroup("Katalogtreffer") {
                    ForEach(Array(titleSuggestions.enumerated()), id: \.offset) { _, entry in
                        Button {
                            onSelectSuggestedEntry(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(entry.number.map(String.init) ?? "✨")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .trailing)
                                    Text(entry.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                                if let collectionName = entry.collectionName {
                                    Text(collectionName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 36)
                                }
                            }
                        }
                    }
                }
                .font(.subheadline)
            }
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
                                Text(entry.number.map(String.init) ?? "✨")
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
            if let duplicateEpisodeWarning {
                Text(duplicateEpisodeWarning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
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
    @Binding var isCollapsed: Bool
    @Binding var isListened: Bool
    @Binding var rating: Int?

    var body: some View {
        CollapsibleEpisodeSection("Status", isCollapsed: $isCollapsed) {
            Toggle("Bereits gehört", isOn: $isListened)
            RatingPicker(rating: $rating)
        }
    }
}

private struct EpisodeMoodSection: View {
    @Binding var isCollapsed: Bool
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
        CollapsibleEpisodeSection("Stimmungen", isCollapsed: $isCollapsed) {
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
    @Binding var isCollapsed: Bool
    @Binding var personalNote: String

    var body: some View {
        CollapsibleEpisodeSection("Persönliche Notiz", isCollapsed: $isCollapsed) {
            TextField("Was möchtest du dir merken?", text: $personalNote, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

private struct EpisodeStreamingSection: View {
    @Binding var isCollapsed: Bool
    @Binding var streamingURL: String

    var body: some View {
        CollapsibleEpisodeSection("Streaming-Link", isCollapsed: $isCollapsed) {
            TextField("https://open.spotify.com/album/…", text: $streamingURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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
                            .foregroundStyle(star <= (rating ?? 0) ? .yellow : .gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
