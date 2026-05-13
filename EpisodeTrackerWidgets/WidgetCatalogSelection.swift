import AppIntents

enum WidgetCatalogSelection {
    static let allValue = "Alle Kataloge"
    static let allTitle = "Alle Kataloge"
}

struct WidgetCatalogOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        let universes = WidgetSnapshotStore.load()?.universes ?? []
        return [WidgetCatalogSelection.allValue] + universes
    }
}

struct EpisodeWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget konfigurieren"
    static var description = IntentDescription("Wählt, welcher Katalog im Widget verwendet werden soll.")

    @Parameter(
        title: "Katalog",
        optionsProvider: WidgetCatalogOptionsProvider()
    )
    var catalog: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Katalog: \(\.$catalog)")
    }
}
