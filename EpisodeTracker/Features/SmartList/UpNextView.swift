import SwiftUI
import SwiftData

struct UpNextView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(SmartListPreferences.hiddenStorageKey) private var hiddenSmartListsRaw = ""
    @AppStorage(SmartListPreferences.orderStorageKey) private var smartListOrderRaw = ""
    @Environment(SavedFilterStore.self) private var savedFilterStore
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @State private var showingInfo: SmartListDefinition?
    @State private var showingEditSheet = false
    @State private var showingNewsOverview = false
    @State private var renameFilter: SavedFilter?
    @State private var renameText = ""
    @State private var recommendationOffset = 0
    @State private var openedEpisode: Episode?
    @State private var showsEmptyLists = false
    @Binding var iPadNavSelection: SmartListNavigation?
    private let usesSelectionMode: Bool

    init(iPadNavSelection: Binding<SmartListNavigation?>? = nil) {
        if let binding = iPadNavSelection {
            _iPadNavSelection = binding
            usesSelectionMode = true
        } else {
            _iPadNavSelection = .constant(nil)
            usesSelectionMode = false
        }
    }

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: episodes
        )
    }

    /// Badge am "Neuigkeiten"-Symbol — unabhängig von `NewsOverviewView`, das
    /// seine Ereignisse erst beim Öffnen als gesehen markiert.
    private var hasUnseenNews: Bool {
        NewsStore().load().events.contains { $0.seenAt == nil }
    }

    private var recommendationCandidates: [UpNextRecommendation] {
        UpNextRecommendation.candidates(from: episodes)
    }

    private func hasItems(_ smartList: SmartListDefinition) -> Bool {
        count(for: smartList) > 0 || smartList == .randomByMood
    }

    private func count(for smartList: SmartListDefinition) -> Int {
        switch smartList {
        case .nextFromCatalog:
            return catalogSuggestions.count
        case .randomByMood:
            return SmartListDefinition.availableMoods(from: episodes, filter: .all, allMoods: moods).count
        default:
            return smartList.episodes(from: episodes).count
        }
    }

    var body: some View {
        List {
            if horizontalSizeClass == .regular {
                UpNextSidebarIntro()
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if let error = EpisodeCatalog.shared.lastRefreshError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .listRowSeparator(.hidden)
            }

            recommendationRow

            let visibleLists = SmartListPreferences.visibleLists(orderRaw: smartListOrderRaw, hiddenRaw: hiddenSmartListsRaw)
            let filledLists = visibleLists.filter(hasItems)
            let emptyLists = visibleLists.filter { !hasItems($0) }

            Section {
                ForEach(filledLists) { smartList in
                    smartListRow(smartList)
                }
            } header: {
                if !recommendationCandidates.isEmpty {
                    Text(String(localized: "UpNext.MoreSuggestions.Header", defaultValue: "Weitere Vorschläge"))
                }
            }

            // Leere Listen eingeklappt statt ausgegraut in voller Höhe
            // (Design Review 2026-11, Befund 4).
            if !emptyLists.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showsEmptyLists) {
                        ForEach(emptyLists) { smartList in
                            smartListRow(smartList)
                        }
                    } label: {
                        Text(AppLocalization.format(
                            "UpNext.EmptyLists.Label",
                            defaultValue: "%lld Listen ohne Folgen",
                            Int64(emptyLists.count)
                        ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if !savedFilterStore.filters.isEmpty {
                Section(String(localized: "UpNext.MyLists.Header", defaultValue: "Meine Listen")) {
                    ForEach(savedFilterStore.filters) { filter in
                        savedFilterRow(filter)
                    }
                }
            }
        }
        .contentMargins(.top, horizontalSizeClass == .regular ? 6 : 0, for: .scrollContent)
        .modifier(AdaptiveUpNextListStyle(isRegularWidth: horizontalSizeClass == .regular))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewsOverview = true
                } label: {
                    Image(systemName: "bell")
                }
                .accessibilityLabel("Neuigkeiten")
                .overlay(alignment: .topTrailing) {
                    if hasUnseenNews {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                            .offset(x: -6, y: 6)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .navigationDestination(item: $openedEpisode) { episode in
            EpisodeDetailView(episode: episode)
        }
        .sheet(isPresented: $showingEditSheet) {
            SmartListEditSheet(
                hiddenSmartListsRaw: $hiddenSmartListsRaw,
                smartListOrderRaw: $smartListOrderRaw
            )
        }
        .sheet(isPresented: $showingNewsOverview) {
            NewsOverviewView()
        }
        .sheet(item: $showingInfo) { smartList in
            SmartListInfoSheet(smartList: smartList)
        }
        .alert(
            String(localized: "SavedFilter.Rename.Title", defaultValue: "Liste umbenennen"),
            isPresented: Binding(get: { renameFilter != nil }, set: { if !$0 { renameFilter = nil } })
        ) {
            TextField(
                String(localized: "SavedFilter.Rename.Placeholder", defaultValue: "Name"),
                text: $renameText
            )
            Button(String(localized: "SavedFilter.Rename.Save", defaultValue: "Speichern")) {
                if var filter = renameFilter, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    filter.name = renameText.trimmingCharacters(in: .whitespaces)
                    savedFilterStore.update(filter)
                }
                renameFilter = nil
            }
            Button(String(localized: "General.Cancel", defaultValue: "Abbrechen"), role: .cancel) {
                renameFilter = nil
            }
        }
    }

    @ViewBuilder
    private var recommendationRow: some View {
        let candidates = recommendationCandidates
        if !candidates.isEmpty {
            let recommendation = candidates[recommendationOffset % candidates.count]
            UpNextRecommendationCard(
                recommendation: recommendation,
                hasAlternatives: candidates.count > 1,
                isCompact: usesSelectionMode,
                onOpen: openAction(for: recommendation),
                onNext: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        recommendationOffset += 1
                    }
                }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    /// iPhone: die Folge öffnen. iPad-Sidebar: Dort gibt es keinen Stack für
    /// Folgen, also die Liste rechts zeigen, aus der die Empfehlung stammt.
    private func openAction(for recommendation: UpNextRecommendation) -> (() -> Void)? {
        guard usesSelectionMode else {
            return { openedEpisode = recommendation.episode }
        }
        let source: SmartListDefinition? = switch recommendation.reason {
        case .continueSeries: .continueListening
        case .bookmarked: .laterListen
        case .open: nil
        }
        guard let source else { return nil }
        return { iPadNavSelection = .detail(source) }
    }

    @ViewBuilder
    private func smartListRow(_ smartList: SmartListDefinition) -> some View {
        let itemCount = count(for: smartList)
        let hasItems = itemCount > 0 || smartList == .randomByMood

        let navValue: SmartListNavigation = smartList == .randomByMood
            ? .moodPicker
            : .detail(smartList)

        let content: SmartListRowContent = {
            switch smartList {
            case .nextFromCatalog:
                return SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: catalogSuggestions.first.map { SmartListDefinition.catalogTeaserText(for: $0.entry) },
                    onInfoTap: { showingInfo = smartList }
                )
            case .randomByMood:
                return SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: itemCount == 0
                        ? String(localized: "SmartList.RandomByMood.PickMood", defaultValue: "Stimmung wählen…")
                        : itemCount == 1
                            ? String(localized: "SmartList.RandomByMood.OneMoodAvailable", defaultValue: "1 Stimmung verfügbar")
                            : AppLocalization.format("SmartList.RandomByMood.MoodsAvailable", defaultValue: "%d Stimmungen verfügbar", itemCount),
                    onInfoTap: { showingInfo = smartList }
                )
            default:
                let firstEpisode = smartList.episodes(from: episodes).first
                return SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: firstEpisode.map { SmartListDefinition.teaserText(for: $0) },
                    onInfoTap: { showingInfo = smartList }
                )
            }
        }()

        if usesSelectionMode {
            Button {
                iPadNavSelection = navValue
            } label: {
                content
            }
            // Ohne eigenen Stil färbt die Sidebar den ganzen Zeilentext in
            // der Akzentfarbe ein.
            .buttonStyle(.plain)
            .listRowBackground(
                iPadNavSelection == navValue
                    ? Color.accentColor.opacity(0.12)
                    : nil
            )
            .opacity(hasItems ? 1 : 0.5)
        } else {
            NavigationLink(value: navValue) {
                content
            }
            .opacity(hasItems ? 1 : 0.5)
        }
    }

    @ViewBuilder
    private func savedFilterRow(_ filter: SavedFilter) -> some View {
        let navValue = SmartListNavigation.savedFilter(filter)

        Group {
            if usesSelectionMode {
                Button {
                    iPadNavSelection = navValue
                } label: {
                    savedFilterRowContent(filter)
                }
                .listRowBackground(
                    iPadNavSelection == navValue
                        ? Color.accentColor.opacity(0.12)
                        : nil
                )
            } else {
                NavigationLink(value: navValue) {
                    savedFilterRowContent(filter)
                }
            }
        }
        .contextMenu {
            Button {
                renameFilter = filter
                renameText = filter.name
            } label: {
                Label(
                    String(localized: "SavedFilter.Action.Rename", defaultValue: "Umbenennen"),
                    systemImage: "pencil"
                )
            }
            Button(role: .destructive) {
                savedFilterStore.delete(filter)
            } label: {
                Label(
                    String(localized: "SavedFilter.Action.Delete", defaultValue: "Löschen"),
                    systemImage: "trash"
                )
            }
        }
    }

    private func savedFilterRowContent(_ filter: SavedFilter) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.tint)
                .frame(width: 28)
            Text(filter.name)
        }
    }
}

private struct UpNextSidebarIntro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Was passt gerade?")
                .font(.headline)
            Text("Kurze Wege zu Fortsetzungen, Zufallsfolgen und offenen Katalogtipps.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AdaptiveUpNextListStyle: ViewModifier {
    let isRegularWidth: Bool

    func body(content: Content) -> some View {
        if isRegularWidth {
            content.listStyle(.sidebar)
        } else {
            content.listStyle(.insetGrouped)
        }
    }
}

private struct SmartListRowContent: View {
    let smartList: SmartListDefinition
    var count: Int = 0
    var teaser: String?
    var onInfoTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Einheitlich in der Akzentfarbe: neun Signalfarben konkurrierten
            // mit der gewählten Akzentfarbe (Design Review 2026-11, Befund 4).
            Image(systemName: smartList.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(smartList.displayName)
                        .font(.body.weight(.semibold))

                    if let onInfoTap {
                        Button {
                            onInfoTap()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(teaser ?? smartList.emptyStateMessage)
                    .font(.caption)
                    .foregroundStyle(teaser != nil ? .secondary : .tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SmartListEditSheet: View {
    @Binding var hiddenSmartListsRaw: String
    @Binding var smartListOrderRaw: String
    @Environment(\.dismiss) private var dismiss
    @State private var order: [SmartListDefinition] = []

    private var hiddenLists: Set<SmartListDefinition> {
        SmartListPreferences.hiddenLists(from: hiddenSmartListsRaw)
    }

    private func isEnabled(_ list: SmartListDefinition) -> Binding<Bool> {
        Binding(
            get: { !hiddenLists.contains(list) },
            set: { enabled in
                var hidden = hiddenLists
                if enabled {
                    hidden.remove(list)
                } else {
                    hidden.insert(list)
                }
                hiddenSmartListsRaw = SmartListPreferences.encodeHidden(hidden)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order) { smartList in
                        Toggle(isOn: isEnabled(smartList)) {
                            Label {
                                Text(smartList.displayName)
                            } icon: {
                                Image(systemName: smartList.icon)
                                    .foregroundStyle(smartListColor(smartList))
                            }
                        }
                    }
                    .onMove { source, destination in
                        order.move(fromOffsets: source, toOffset: destination)
                        smartListOrderRaw = SmartListPreferences.encodeOrder(order)
                    }
                } footer: {
                    Text("Deaktivierte Listen werden ausgeblendet. Halte und ziehe um die Reihenfolge zu ändern.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Smart Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            order = SmartListPreferences.orderedLists(from: smartListOrderRaw)
        }
    }
}

private func smartListColor(_ smartList: SmartListDefinition) -> Color {
    switch smartList.accentColor {
    case "cyan": .cyan
    case "red": .red
    case "blue": .blue
    case "green": .green
    case "orange": .orange
    case "yellow": .yellow
    case "purple": .purple
    case "pink": .pink
    default: .accentColor
    }
}

private struct SmartListInfoSheet: View {
    let smartList: SmartListDefinition

    @Environment(\.dismiss) private var dismiss

    private var color: Color {
        switch smartList.accentColor {
        case "cyan": .cyan
        case "red": .red
        case "blue": .blue
        case "green": .green
        case "orange": .orange
        case "yellow": .yellow
        case "purple": .purple
        case "pink": .pink
        default: .accentColor
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: smartList.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(smartList.displayName)
                    .font(.title2.weight(.bold))

                Text(smartList.infoText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
