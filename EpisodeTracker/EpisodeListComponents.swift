import SwiftUI

struct EpisodeStatusFilterBar: View {
    @Binding var selection: EpisodeStatusFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(EpisodeStatusFilter.allCases, id: \.self) { filter in
                    EpisodeFilterChip(
                        label: filter.displayName,
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
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 20, alignment: .center)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isCollapsed)

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
    var onSaveFilter: (() -> Void)? = nil

    var body: some View {
        Menu {
            sortButtons
            universeMenu
            statusMenu

            if controls.hasActiveFilter {
                Divider()
                if let onSaveFilter {
                    Button {
                        onSaveFilter()
                    } label: {
                        Label(
                            String(localized: "EpisodeList.Filter.SaveAsList",
                                   defaultValue: "Als Liste speichern"),
                            systemImage: "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                }
                Button(
                    String(localized: "EpisodeList.Filter.Reset", defaultValue: "Filter zurücksetzen"),
                    role: .destructive
                ) {
                    controls.resetFilters(resetMood: resetsMoodFilter)
                }
            }
        } label: {
            Label(
                String(localized: "EpisodeList.SortAndFilter", defaultValue: "Sortieren und filtern"),
                systemImage: "arrow.up.arrow.down"
            )
        }
    }

    @ViewBuilder
    private var sortButtons: some View {
        ForEach(EpisodeSortOrder.allCases, id: \.self) { sortOrder in
            Button {
                controls.sortOrder = sortOrder
            } label: {
                EpisodeListMenuLabel(
                    text: sortOrder.displayName,
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
                    text: String(localized: "Selection.All", defaultValue: "Alle"),
                    isSelected: controls.filterUniverse == nil
                )
            }

            ForEach(Array(universes.enumerated()), id: \.offset) { _, universe in
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
                        text: filter.displayName,
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

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

struct LibrarySnapshotView: View {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard episodeCount > 0 else { return 0 }
        return Double(listenedCount) / Double(episodeCount)
    }

    private var appAccentColor: AppAccentColor {
        AppAccentColor.resolved(from: appAccentColorRawValue)
    }

    private var accentTintOpacity: Double {
        colorScheme == .dark ? 0.10 : 0.06
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dein Hörstand")
                        .font(.headline)
                    Text(AppLocalization.format(
                        "EpisodeList.ProgressSummary",
                        defaultValue: "%lld von %lld Folgen gehört",
                        Int64(listenedCount),
                        Int64(episodeCount)
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            ProgressView(value: progress)

            HStack(spacing: 12) {
                SnapshotMetric(value: "\(episodeCount)", label: "Folgen")
                Divider()
                SnapshotMetric(value: "\(openCount)", label: "Offen")
                Divider()
                SnapshotMetric(value: "\(totalListens)", label: "Hördurchgänge")
            }
            .frame(minHeight: 44)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(appAccentColor.color.opacity(accentTintOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SnapshotMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Mood Filter Bar

struct MoodFilterBar: View {
    let moods: [Mood]
    @Binding var selection: Mood?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                MoodChip(label: String(localized: "Selection.All", defaultValue: "Alle"), isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(moods) { mood in
                    MoodChip(
                        label: [mood.iconName, mood.name]
                            .compactMap { $0 }
                            .joined(separator: " "),
                        isSelected: selection == mood
                    ) {
                        selection = mood
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MoodChip: View {
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
