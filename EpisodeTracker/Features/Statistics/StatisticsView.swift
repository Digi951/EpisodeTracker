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
    @State private var yearInReviewYear: YearInReviewSelection?

    /// Jahr für die Karte „Dein Hörjahr“: im Januar das Vorjahr, sonst das
    /// laufende; fehlen dort Einträge, das letzte Jahr mit Einträgen.
    private var yearInReviewCardYear: Int? {
        let years = YearInReviewEngine.availableYears(episodes: episodes)
        let preferred = YearInReviewEngine.defaultYear(on: .now)
        return years.contains(preferred) ? preferred : years.last
    }

    @ViewBuilder
    private var yearInReviewCard: some View {
        if let year = yearInReviewCardYear {
            YearInReviewCard(
                year: year,
                episodeCount: YearInReviewEngine(episodes: episodes, year: year).episodeCount
            ) {
                yearInReviewYear = YearInReviewSelection(year: year)
            }
        }
    }

    private func availableOverviewItems(statistics: StatisticsSnapshot) -> [StatisticsOverviewItem] {
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
                    // Lokalisiertes Dezimaltrennzeichen ("3,9" in DE/FR) statt "%.1f".
                    // Kein Stern hinter der Zahl: Das Kachel-Icon zeigt ihn schon.
                    value: avg.formatted(.number.precision(.fractionLength(1)))
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

    private func visibleOverviewStats(availableItems: [StatisticsOverviewItem]) -> [StatisticsOverviewItem] {
        let availableKinds = Set(availableItems.map(\.kind))
        let order = StatisticsOverviewPreferences.orderedItems(from: overviewOrderRaw, availableKinds: availableKinds)
        let hidden = StatisticsOverviewPreferences.hiddenItems(from: hiddenOverviewItemsRaw, availableKinds: availableKinds)
        let byKind = Dictionary(uniqueKeysWithValues: availableItems.map { ($0.kind, $0) })
        return order.compactMap { kind in
            guard !hidden.contains(kind) else { return nil }
            return byKind[kind]
        }
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

    private func moodSummaryText(statistics: StatisticsSnapshot) -> String {
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
        let statistics = StatisticsSnapshot(episodes: episodes)
        let availableItems = availableOverviewItems(statistics: statistics)

        Group {
            if horizontalSizeClass == .regular {
                iPadBody(statistics: statistics, availableItems: availableItems)
            } else {
                iPhoneBody(statistics: statistics, availableItems: availableItems)
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
        .sheet(item: $yearInReviewYear) { selection in
            YearInReviewView(episodes: episodes, year: selection.year)
        }
        .sheet(isPresented: $showingCustomization) {
            StatisticsCustomizationView(
                sectionOrderRaw: $sectionOrderRaw,
                hiddenSectionsRaw: $hiddenSectionsRaw,
                overviewOrderRaw: $overviewOrderRaw,
                hiddenOverviewItemsRaw: $hiddenOverviewItemsRaw,
                items: availableItems
            )
        }
    }

    private func iPhoneBody(statistics: StatisticsSnapshot, availableItems: [StatisticsOverviewItem]) -> some View {
        List {
            if episodes.isEmpty {
                StatisticsEmptyState()
            } else {
                yearInReviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                StatisticsPhoneContent(
                    visibleSections: visibleSections,
                    visibleOverviewStats: visibleOverviewStats(availableItems: availableItems),
                    topRated: statistics.topRated,
                    moodDistribution: statistics.moodDistribution,
                    moodSummaryText: moodSummaryText(statistics: statistics),
                    heroEpisode: statistics.heroEpisode,
                    ratingDistribution: statistics.ratingDistribution
                )
            }
        }
    }

    private func iPadBody(statistics: StatisticsSnapshot, availableItems: [StatisticsOverviewItem]) -> some View {
        GeometryReader { geometry in
            let layout = StatisticsRegularLayout(containerWidth: geometry.size.width)

            ScrollView {
                if episodes.isEmpty {
                    StatisticsEmptyState()
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        yearInReviewCard
                        StatisticsPadContent(
                        layout: layout,
                        visibleSections: visibleSections,
                        visibleOverviewStats: visibleOverviewStats(availableItems: availableItems),
                        topRated: statistics.topRated,
                        moodDistribution: statistics.moodDistribution,
                        moodSummaryText: moodSummaryText(statistics: statistics),
                        heroEpisode: statistics.heroEpisode,
                        ratingDistribution: statistics.ratingDistribution
                        )
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
