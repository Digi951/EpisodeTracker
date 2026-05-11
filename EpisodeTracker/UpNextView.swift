import SwiftUI
import SwiftData

struct UpNextView: View {
    @Query private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]

    var body: some View {
        List {
            ForEach(SmartListDefinition.allCases) { smartList in
                smartListRow(smartList)
            }
        }
    }

    @ViewBuilder
    private func smartListRow(_ smartList: SmartListDefinition) -> some View {
        switch smartList {
        case .zufaelligNachStimmung:
            NavigationLink(value: SmartListNavigation.moodPicker) {
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: "Stimmung wählen..."
                )
            }
        default:
            NavigationLink(value: SmartListNavigation.detail(smartList)) {
                let firstEpisode = smartList.episodes(from: episodes).first
                SmartListRowContent(
                    icon: smartList.icon,
                    name: smartList.displayName,
                    teaser: firstEpisode.map { SmartListDefinition.teaserText(for: $0) },
                    emptyText: smartList.emptyStateMessage
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

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))

                Text(teaser ?? emptyText)
                    .font(.caption)
                    .foregroundStyle(teaser != nil ? .secondary : .tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
