import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("statisticsOverviewOrder") private var overviewOrderRaw = ""
    @AppStorage("statisticsHiddenOverviewItems") private var hiddenOverviewItemsRaw = ""
    @Query private var episodes: [Episode]
    @State private var showingCustomization = false

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
            .sorted {
                let leftRating = $0.rating ?? 0
                let rightRating = $1.rating ?? 0
                if leftRating != rightRating {
                    return leftRating > rightRating
                }

                let leftUniverse = $0.universe?.name ?? "Allgemein"
                let rightUniverse = $1.universe?.name ?? "Allgemein"
                if leftUniverse != rightUniverse {
                    return leftUniverse.localizedCompare(rightUniverse) == .orderedAscending
                }

                return $0.episodeNumber < $1.episodeNumber
            }
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

    private var availableOverviewItems: [StatisticsOverviewItem] {
        var items = [
            StatisticsOverviewItem(kind: .episodes, value: "\(episodes.count)"),
            StatisticsOverviewItem(kind: .listened, value: "\(listenedCount)"),
            StatisticsOverviewItem(kind: .open, value: "\(unlistenedCount)"),
            StatisticsOverviewItem(kind: .totalListens, value: "\(totalListens)")
        ]

        if let avg = averageRating {
            items.append(
                StatisticsOverviewItem(
                    kind: .averageRating,
                    value: String(format: "%.1f ⭐", avg)
                )
            )
        }

        return items
    }

    private var overviewOrder: [StatisticsOverviewKind] {
        StatisticsOverviewPreferences.orderedItems(
            from: overviewOrderRaw,
            availableKinds: Set(availableOverviewItems.map(\.kind))
        )
    }

    private var hiddenOverviewItems: Set<StatisticsOverviewKind> {
        StatisticsOverviewPreferences.hiddenItems(
            from: hiddenOverviewItemsRaw,
            availableKinds: Set(availableOverviewItems.map(\.kind))
        )
    }

    private var visibleOverviewStats: [StatisticsOverviewItem] {
        let byKind = Dictionary(uniqueKeysWithValues: availableOverviewItems.map { ($0.kind, $0) })
        return overviewOrder.compactMap { kind in
            guard !hiddenOverviewItems.contains(kind) else { return nil }
            return byKind[kind]
        }
    }

    private var moodSummaryText: String {
        guard !moodDistribution.isEmpty else {
            return "Noch keine Stimmungen in deiner Bibliothek"
        }

        let topMoods = moodDistribution.prefix(2).map { mood, count in
            "\(mood.iconName ?? "") \(mood.name) (\(count))"
        }
        return topMoods.joined(separator: " · ")
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
        .toolbar {
            if !episodes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bearbeiten") {
                        showingCustomization = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomization) {
            StatisticsCustomizationView(
                items: availableOverviewItems,
                order: overviewOrder,
                hiddenItems: hiddenOverviewItems
            ) { updatedOrder, updatedHiddenItems in
                overviewOrderRaw = StatisticsOverviewPreferences.encodeOrder(updatedOrder)
                hiddenOverviewItemsRaw = StatisticsOverviewPreferences.encodeHidden(updatedHiddenItems)
            }
        }
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
                    ForEach(visibleOverviewStats) { stat in
                        StatRow(label: stat.kind.title, value: stat.value)
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
                            TopRatedStatisticRow(episode: episode)
                        }
                    }
                }

                Section("Stimmungen") {
                    NavigationLink {
                        MoodStatisticsDetailView(moodDistribution: moodDistribution)
                    } label: {
                        StatisticNavigationRow(
                            title: "Stimmungen ansehen",
                            detail: moodSummaryText
                        )
                    }
                }
            }
        }
    }

    private var iPadBody: some View {
        GeometryReader { geometry in
            let layout = StatisticsRegularLayout(containerWidth: geometry.size.width)

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
                            columns: layout.summaryColumns,
                            spacing: 16
                        ) {
                            ForEach(visibleOverviewStats) { stat in
                                StatSummaryTile(stat: stat)
                            }
                        }

                        LazyVGrid(
                            columns: layout.detailColumns,
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
                                            TopRatedStatisticRow(episode: episode)
                                        }
                                    }
                                }
                            }

                            StatisticPanel(title: "Stimmungen", systemImage: "tag") {
                                NavigationLink {
                                    MoodStatisticsDetailView(moodDistribution: moodDistribution)
                                } label: {
                                    StatisticNavigationRow(
                                        title: "Stimmungen ansehen",
                                        detail: moodSummaryText
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: layout.contentWidth, alignment: .leading)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.vertical, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

enum StatisticsOverviewKind: String, CaseIterable, Identifiable {
    case episodes
    case listened
    case open
    case totalListens
    case averageRating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .episodes: "Folgen"
        case .listened: "Gehört"
        case .open: "Offen"
        case .totalListens: "Hördurchgänge"
        case .averageRating: "Schnitt"
        }
    }

    var systemImage: String {
        switch self {
        case .episodes: "list.number"
        case .listened: "checkmark.circle"
        case .open: "circle"
        case .totalListens: "ear"
        case .averageRating: "star"
        }
    }
}

enum StatisticsOverviewPreferences {
    static func orderedItems(
        from rawValue: String,
        availableKinds: Set<StatisticsOverviewKind>
    ) -> [StatisticsOverviewKind] {
        let saved = rawValue
            .split(separator: ",")
            .compactMap { StatisticsOverviewKind(rawValue: String($0)) }
            .filter { availableKinds.contains($0) }

        var result: [StatisticsOverviewKind] = []
        for section in saved where !result.contains(section) {
            result.append(section)
        }
        for section in StatisticsOverviewKind.allCases where availableKinds.contains(section) && !result.contains(section) {
            result.append(section)
        }
        return result
    }

    static func hiddenItems(
        from rawValue: String,
        availableKinds: Set<StatisticsOverviewKind>
    ) -> Set<StatisticsOverviewKind> {
        Set(
            rawValue
                .split(separator: ",")
                .compactMap { StatisticsOverviewKind(rawValue: String($0)) }
                .filter { availableKinds.contains($0) }
        )
    }

    static func encodeOrder(_ order: [StatisticsOverviewKind]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    static func encodeHidden(_ hiddenItems: Set<StatisticsOverviewKind>) -> String {
        hiddenItems.map(\.rawValue).sorted().joined(separator: ",")
    }
}

private struct StatisticsOverviewItem: Identifiable {
    let kind: StatisticsOverviewKind
    let value: String

    var id: StatisticsOverviewKind { kind }
}

struct StatisticsRegularLayout {
    let contentWidth: CGFloat
    let horizontalPadding: CGFloat
    let summaryColumns: [GridItem]
    let detailColumns: [GridItem]

    init(containerWidth: CGFloat) {
        let safeWidth = max(containerWidth, 320)
        let usesTwoDetailColumns = safeWidth >= 920

        if usesTwoDetailColumns {
            contentWidth = min(1100, safeWidth - 64)
            summaryColumns = [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
            ]
            detailColumns = [
                GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16),
                GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16)
            ]
        } else {
            contentWidth = min(760, safeWidth - 48)
            summaryColumns = [
                GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
            ]
            detailColumns = [
                GridItem(.flexible(minimum: 320, maximum: 760), spacing: 16)
            ]
        }

        horizontalPadding = max(24, (safeWidth - contentWidth) / 2)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label, value: value)
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
        let universeName = episode.universe?.name ?? "Allgemein"
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
        .navigationTitle("Stimmungen")
    }
}

private struct StatisticsCustomizationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var order: [StatisticsOverviewKind]
    @State private var hiddenItems: Set<StatisticsOverviewKind>

    let items: [StatisticsOverviewItem]
    let onSave: ([StatisticsOverviewKind], Set<StatisticsOverviewKind>) -> Void

    init(
        items: [StatisticsOverviewItem],
        order: [StatisticsOverviewKind],
        hiddenItems: Set<StatisticsOverviewKind>,
        onSave: @escaping ([StatisticsOverviewKind], Set<StatisticsOverviewKind>) -> Void
    ) {
        self.items = items
        _order = State(initialValue: order)
        _hiddenItems = State(initialValue: hiddenItems)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Bereiche") {
                    ForEach(order) { section in
                        Toggle(isOn: visibilityBinding(for: section)) {
                            HStack {
                                Label(section.title, systemImage: section.systemImage)
                                Spacer()
                                if let item = items.first(where: { $0.kind == section }) {
                                    Text(item.value)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onMove(perform: move)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Statistiken")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        onSave(order, hiddenItems)
                        dismiss()
                    }
                }
            }
        }
    }

    private func visibilityBinding(for section: StatisticsOverviewKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenItems.contains(section) },
            set: { isVisible in
                if isVisible {
                    hiddenItems.remove(section)
                } else if visibleCount > 1 {
                    hiddenItems.insert(section)
                }
            }
        )
    }

    private var visibleCount: Int {
        order.filter { !hiddenItems.contains($0) }.count
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
}
