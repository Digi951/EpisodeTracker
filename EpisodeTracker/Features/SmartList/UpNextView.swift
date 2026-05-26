import SwiftUI
import SwiftData

struct UpNextView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @State private var showingInfo: SmartListDefinition?
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

            ForEach(SmartListDefinition.allCases) { smartList in
                smartListRow(smartList)
            }
        }
        .contentMargins(.top, horizontalSizeClass == .regular ? 6 : 0, for: .scrollContent)
        .modifier(AdaptiveUpNextListStyle(isRegularWidth: horizontalSizeClass == .regular))
        .sheet(item: $showingInfo) { smartList in
            SmartListInfoSheet(smartList: smartList)
        }
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
        HStack(spacing: 14) {
            Image(systemName: smartList.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                    .foregroundStyle(color)
            }
        }
        .padding(.vertical, 4)
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
