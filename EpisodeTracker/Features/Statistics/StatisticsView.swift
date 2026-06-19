import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("statisticsSectionOrder") private var sectionOrderRaw = ""
    @AppStorage("statisticsHiddenSections") private var hiddenSectionsRaw = ""
    @AppStorage("statisticsOverviewOrder") private var overviewOrderRaw = ""
    @AppStorage("statisticsHiddenOverviewItems") private var hiddenOverviewItemsRaw = ""
    @Query private var episodes: [Episode]
    @State private var showingCustomization = false

    private var statistics: StatisticsSnapshot {
        StatisticsSnapshot(episodes: episodes)
    }

    private var availableOverviewItems: [StatisticsOverviewItem] {
        var items = [
            StatisticsOverviewItem(kind: .episodes, value: "\(episodes.count)"),
            StatisticsOverviewItem(kind: .listened, value: "\(statistics.listenedCount)"),
            StatisticsOverviewItem(kind: .open, value: "\(statistics.unlistenedCount)"),
            StatisticsOverviewItem(kind: .totalListens, value: "\(statistics.totalListens)")
        ]

        if let avg = statistics.averageRating {
            items.append(
                StatisticsOverviewItem(
                    kind: .averageRating,
                    value: String(format: "%.1f ⭐", avg)
                )
            )
        }

        if statistics.favoriteCount > 0 {
            items.append(
                StatisticsOverviewItem(kind: .favorites, value: "\(statistics.favoriteCount)")
            )
        }

        if statistics.bookmarkedCount > 0 {
            items.append(
                StatisticsOverviewItem(kind: .bookmarked, value: "\(statistics.bookmarkedCount)")
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

    private var sectionOrder: [StatisticsSectionKind] {
        StatisticsOverviewPreferences.orderedSections(from: sectionOrderRaw)
    }

    private var hiddenSections: Set<StatisticsSectionKind> {
        StatisticsOverviewPreferences.hiddenSections(from: hiddenSectionsRaw)
    }

    private var visibleSections: [StatisticsSectionKind] {
        sectionOrder.filter { !hiddenSections.contains($0) }
    }

    private var visibleOverviewStats: [StatisticsOverviewItem] {
        let byKind = Dictionary(uniqueKeysWithValues: availableOverviewItems.map { ($0.kind, $0) })
        return overviewOrder.compactMap { kind in
            guard !hiddenOverviewItems.contains(kind) else { return nil }
            return byKind[kind]
        }
    }

    private var moodSummaryText: String {
        guard !statistics.moodDistribution.isEmpty else {
            return String(
                localized: "Noch keine Stimmungen in deiner Bibliothek",
                defaultValue: "Noch keine Stimmungen in deiner Bibliothek"
            )
        }

        let topMoods = statistics.moodDistribution.prefix(2).map { mood, count in
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
                    Button {
                        showingCustomization = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomization) {
            StatisticsCustomizationView(
                sectionOrderRaw: $sectionOrderRaw,
                hiddenSectionsRaw: $hiddenSectionsRaw,
                overviewOrderRaw: $overviewOrderRaw,
                hiddenOverviewItemsRaw: $hiddenOverviewItemsRaw,
                items: availableOverviewItems
            )
        }
    }

    private var iPhoneBody: some View {
        List {
            if episodes.isEmpty {
                StatisticsEmptyState()
            } else {
                StatisticsPhoneContent(
                    visibleSections: visibleSections,
                    visibleOverviewStats: visibleOverviewStats,
                    topRated: statistics.topRated,
                    moodDistribution: statistics.moodDistribution,
                    moodSummaryText: moodSummaryText
                )
            }
        }
    }

    private var iPadBody: some View {
        GeometryReader { geometry in
            let layout = StatisticsRegularLayout(containerWidth: geometry.size.width)

            ScrollView {
                if episodes.isEmpty {
                    StatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    StatisticsPadContent(
                        layout: layout,
                        visibleSections: visibleSections,
                        visibleOverviewStats: visibleOverviewStats,
                        topRated: statistics.topRated,
                        moodDistribution: statistics.moodDistribution,
                        moodSummaryText: moodSummaryText
                    )
                    .frame(maxWidth: layout.contentWidth, alignment: .leading)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.vertical, 24)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
