import SwiftUI

struct EpisodeStatusFilterBar: View {
    @Binding var selection: EpisodeStatusFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(EpisodeStatusFilter.allCases, id: \.self) { filter in
                    EpisodeFilterChip(
                        label: filter.rawValue,
                        isSelected: selection == filter
                    ) {
                        selection = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

struct EpisodeFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                    in: .capsule
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct EpisodeGroupHeader: View {
    let group: EpisodeListGroup
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(group.progressText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }

                    Text(group.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    ProgressView(value: group.progress)
                        .tint(Color.accentColor.opacity(0.75))
                        .scaleEffect(y: 0.6, anchor: .center)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityLabel("\(group.title), \(group.summary), \(group.progressText)")
        .accessibilityHint(isCollapsed ? "Zum Aufklappen tippen" : "Zum Einklappen tippen")
    }
}

struct EpisodeListSortFilterMenu: View {
    @Binding var controls: EpisodeListControlsState
    let universes: [Universe]
    var resetsMoodFilter = true

    var body: some View {
        Menu {
            sortButtons
            universeMenu
            statusMenu

            if controls.hasActiveFilter {
                Button("Filter zurücksetzen", role: .destructive) {
                    controls.resetFilters(resetMood: resetsMoodFilter)
                }
            }
        } label: {
            Label("Sortieren und filtern", systemImage: "arrow.up.arrow.down")
        }
    }

    @ViewBuilder
    private var sortButtons: some View {
        ForEach(EpisodeSortOrder.allCases, id: \.self) { sortOrder in
            Button {
                controls.sortOrder = sortOrder
            } label: {
                EpisodeListMenuLabel(
                    text: sortOrder.rawValue,
                    isSelected: controls.sortOrder == sortOrder
                )
            }
        }
    }

    private var universeMenu: some View {
        Menu("Katalog") {
            Button {
                controls.filterUniverse = nil
            } label: {
                EpisodeListMenuLabel(
                    text: "Alle",
                    isSelected: controls.filterUniverse == nil
                )
            }

            ForEach(universes) { universe in
                Button {
                    controls.filterUniverse = universe
                } label: {
                    EpisodeListMenuLabel(
                        text: universe.name,
                        isSelected: controls.filterUniverse?.id == universe.id
                    )
                }
            }
        }
    }

    private var statusMenu: some View {
        Menu("Status") {
            ForEach(EpisodeStatusFilter.allCases, id: \.self) { filter in
                Button {
                    controls.statusFilter = filter
                } label: {
                    EpisodeListMenuLabel(
                        text: filter.rawValue,
                        isSelected: controls.statusFilter == filter
                    )
                }
            }
        }
    }
}

private struct EpisodeListMenuLabel: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(text)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}
