import SwiftUI
import SwiftData

struct UpNextView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @State private var showingInfo: SmartListDefinition?

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: episodes
        )
    }

    private func count(for smartList: SmartListDefinition) -> Int {
        switch smartList {
        case .naechsteAusKatalog:
            return catalogSuggestions.count
        case .zufaelligNachStimmung:
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
        let hasItems = itemCount > 0 || smartList == .zufaelligNachStimmung

        switch smartList {
        case .naechsteAusKatalog:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: catalogSuggestions.first.map { SmartListDefinition.catalogTeaserText(for: $0.entry) },
                    onInfoTap: { showingInfo = smartList }
                )
            }
            .opacity(hasItems ? 1 : 0.5)
        case .zufaelligNachStimmung:
            NavigationLink(value: SmartListNavigation.moodPicker) {
                SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: "Stimmung wählen…",
                    onInfoTap: { showingInfo = smartList }
                )
            }
        default:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                let firstEpisode = smartList.episodes(from: episodes).first
                SmartListRowContent(
                    smartList: smartList,
                    count: itemCount,
                    teaser: firstEpisode.map { SmartListDefinition.teaserText(for: $0) },
                    onInfoTap: { showingInfo = smartList }
                )
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
        case "blue": .blue
        case "green": .green
        case "orange": .orange
        case "red": .red
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
        case "blue": .blue
        case "green": .green
        case "orange": .orange
        case "red": .red
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
