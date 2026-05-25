struct StatisticsOverviewItem: Identifiable {
    let kind: StatisticsOverviewKind
    let value: String

    var id: StatisticsOverviewKind { kind }
}
