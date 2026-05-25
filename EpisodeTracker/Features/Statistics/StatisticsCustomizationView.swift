import SwiftUI

struct StatisticsCustomizationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sectionOrder: [StatisticsSectionKind]
    @State private var hiddenSections: Set<StatisticsSectionKind>
    @State private var order: [StatisticsOverviewKind]
    @State private var hiddenItems: Set<StatisticsOverviewKind>

    let items: [StatisticsOverviewItem]
    let onSave: ([StatisticsSectionKind], Set<StatisticsSectionKind>, [StatisticsOverviewKind], Set<StatisticsOverviewKind>) -> Void

    init(
        sectionOrder: [StatisticsSectionKind],
        hiddenSections: Set<StatisticsSectionKind>,
        items: [StatisticsOverviewItem],
        order: [StatisticsOverviewKind],
        hiddenItems: Set<StatisticsOverviewKind>,
        onSave: @escaping ([StatisticsSectionKind], Set<StatisticsSectionKind>, [StatisticsOverviewKind], Set<StatisticsOverviewKind>) -> Void
    ) {
        self.items = items
        _sectionOrder = State(initialValue: sectionOrder)
        _hiddenSections = State(initialValue: hiddenSections)
        _order = State(initialValue: order)
        _hiddenItems = State(initialValue: hiddenItems)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Statistikbereiche") {
                    ForEach(sectionOrder) { section in
                        Toggle(isOn: sectionVisibilityBinding(for: section)) {
                            Label(section.title, systemImage: section.systemImage)
                        }
                    }
                    .onMove(perform: moveSection)
                }

                Section("Übersichtswerte") {
                    ForEach(order) { section in
                        StatisticsOverviewCustomizationRow(
                            section: section,
                            value: overviewValue(for: section),
                            isVisible: visibilityBinding(for: section)
                        )
                    }
                    .onMove(perform: move)
                    .moveDisabled(!isOverviewSectionVisible)
                }
                .disabled(!isOverviewSectionVisible)
                .opacity(isOverviewSectionVisible ? 1 : 0.45)
                .animation(.easeInOut(duration: 0.18), value: isOverviewSectionVisible)
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
                        onSave(sectionOrder, hiddenSections, order, hiddenItems)
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

    private func sectionVisibilityBinding(for section: StatisticsSectionKind) -> Binding<Bool> {
        Binding(
            get: { !hiddenSections.contains(section) },
            set: { isVisible in
                if isVisible {
                    hiddenSections.remove(section)
                } else if visibleSectionCount > 1 {
                    hiddenSections.insert(section)
                }
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

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }

    private func moveSection(from source: IndexSet, to destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
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
