import SwiftUI

struct StatisticsCustomizationView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sectionOrderRaw: String
    @Binding var hiddenSectionsRaw: String
    @Binding var overviewOrderRaw: String
    @Binding var hiddenOverviewItemsRaw: String

    let items: [StatisticsOverviewItem]

    @State private var sectionOrder: [StatisticsSectionKind] = []
    @State private var order: [StatisticsOverviewKind] = []

    private var hiddenSections: Set<StatisticsSectionKind> {
        StatisticsOverviewPreferences.hiddenSections(from: hiddenSectionsRaw)
    }

    private var hiddenItems: Set<StatisticsOverviewKind> {
        StatisticsOverviewPreferences.hiddenItems(
            from: hiddenOverviewItemsRaw,
            availableKinds: Set(items.map(\.kind))
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sectionOrder) { section in
                        Toggle(isOn: sectionVisibilityBinding(for: section)) {
                            Label(section.title, systemImage: section.systemImage)
                        }
                    }
                    .onMove { source, destination in
                        sectionOrder.move(fromOffsets: source, toOffset: destination)
                        sectionOrderRaw = StatisticsOverviewPreferences.encodeSectionOrder(sectionOrder)
                    }
                } header: {
                    Text("Statistikbereiche")
                }

                Section {
                    ForEach(order) { section in
                        StatisticsOverviewCustomizationRow(
                            section: section,
                            value: overviewValue(for: section),
                            isVisible: visibilityBinding(for: section)
                        )
                    }
                    .onMove { source, destination in
                        order.move(fromOffsets: source, toOffset: destination)
                        overviewOrderRaw = StatisticsOverviewPreferences.encodeOrder(order)
                    }
                    .moveDisabled(!isOverviewSectionVisible)
                } header: {
                    Text("Übersichtswerte")
                }
                .disabled(!isOverviewSectionVisible)
                .opacity(isOverviewSectionVisible ? 1 : 0.45)
                .animation(.easeInOut(duration: 0.18), value: isOverviewSectionVisible)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Statistiken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            sectionOrder = StatisticsOverviewPreferences.orderedSections(from: sectionOrderRaw)
            order = StatisticsOverviewPreferences.orderedItems(
                from: overviewOrderRaw,
                availableKinds: Set(items.map(\.kind))
            )
        }
    }

    private func visibilityBinding(for section: StatisticsOverviewKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenItems.contains(section) },
            set: { isVisible in
                var hidden = hiddenItems
                if isVisible {
                    hidden.remove(section)
                } else if visibleCount > 1 {
                    hidden.insert(section)
                }
                hiddenOverviewItemsRaw = StatisticsOverviewPreferences.encodeHidden(hidden)
            }
        )
    }

    private func sectionVisibilityBinding(for section: StatisticsSectionKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenSections.contains(section) },
            set: { isVisible in
                var hidden = hiddenSections
                if isVisible {
                    hidden.remove(section)
                } else if visibleSectionCount > 1 {
                    hidden.insert(section)
                }
                hiddenSectionsRaw = StatisticsOverviewPreferences.encodeHiddenSections(hidden)
            }
        )
    }

    private func overviewValue(for section: StatisticsOverviewKind) -> String? {
        items.first(where: { $0.kind == section })?.value
    }

    private var visibleCount: Int {
        order.filter { !hiddenItems.contains($0) }.count
    }

    private var visibleSectionCount: Int {
        sectionOrder.filter { !hiddenSections.contains($0) }.count
    }

    private var isOverviewSectionVisible: Bool {
        !hiddenSections.contains(.overview)
    }
}

private struct StatisticsOverviewCustomizationRow: View {
    let section: StatisticsOverviewKind
    let value: String?
    @Binding var isVisible: Bool

    var body: some View {
        Toggle(isOn: $isVisible) {
            HStack {
                Label(section.title, systemImage: section.systemImage)
                Spacer()
                if let value {
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
