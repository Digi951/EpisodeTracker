import SwiftUI
import SwiftData

struct UpNextView: View {
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @State private var showingInfo: SmartListDefinition?

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: episodes
        )
    }

    var body: some View {
        List {
            ForEach(SmartListDefinition.allCases) { smartList in
                smartListRow(smartList)
            }
        }
        .sheet(item: $showingInfo) { smartList in
            SmartListInfoSheet(smartList: smartList)
        }
    }

    @ViewBuilder
    private func smartListRow(_ smartList: SmartListDefinition) -> some View {
        switch smartList {
        case .naechsteAusKatalog:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                let firstSuggestion = catalogSuggestions.first
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: firstSuggestion.map { SmartListDefinition.catalogTeaserText(for: $0.entry) },
                    emptyText: smartList.emptyStateMessage,
                    onInfoTap: { showingInfo = smartList }
                )
            }
        case .zufaelligNachStimmung:
            NavigationLink(value: SmartListNavigation.moodPicker) {
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: "Stimmung wählen...",
                    onInfoTap: { showingInfo = smartList }
                )
            }
        default:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                let firstEpisode = smartList.episodes(from: episodes).first
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: firstEpisode.map { SmartListDefinition.teaserText(for: $0) },
                    emptyText: smartList.emptyStateMessage,
                    onInfoTap: { showingInfo = smartList }
                )
            }
        }
    }
}

private struct SmartListRowContent: View {
    let icon: String
    let name: String
    var teaser: String?
    var emptyText: String = "Keine Vorschläge"
    var onInfoTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
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

                Text(teaser ?? emptyText)
                    .font(.caption)
                    .foregroundStyle(teaser != nil ? .secondary : .tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SmartListInfoSheet: View {
    let smartList: SmartListDefinition

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(smartList.icon)
                    .font(.system(size: 48))

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
