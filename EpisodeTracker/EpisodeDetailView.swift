import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    @State private var showingEdit = false

    var body: some View {
        List {
            Section {
                LabeledContent("Nummer", value: "\(episode.episodeNumber)")
                LabeledContent("Titel", value: episode.title)
                LabeledContent("Erscheinungsjahr", value: "\(episode.releaseYear)")
            }

            Section("Status") {
                LabeledContent("Gehört") {
                    Image(systemName: episode.isListened ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(episode.isListened ? .green : .secondary)
                }
                if episode.listenCount > 0 {
                    LabeledContent("Anzahl gehört", value: "\(episode.listenCount)")
                }
                if let lastListened = episode.lastListenedAt {
                    LabeledContent("Zuletzt gehört", value: lastListened.formatted(date: .abbreviated, time: .omitted))
                }
                if let rating = episode.rating {
                    LabeledContent("Bewertung") {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
            }

            if !episode.moods.isEmpty {
                Section("Stimmungen") {
                    FlowLayout(spacing: 8) {
                        ForEach(episode.moods) { mood in
                            Text("\(mood.iconName ?? "") \(mood.name)")
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.fill.tertiary, in: .capsule)
                        }
                    }
                }
            }

            if let note = episode.personalNote, !note.isEmpty {
                Section("Persönliche Notiz") {
                    Text(note)
                }
            }
        }
        .navigationTitle("Folge \(episode.episodeNumber)")
        .toolbar {
            Button {
                episode.isListened = true
                episode.listenCount += 1
                episode.lastListenedAt = .now
            } label: {
                Label("Gehört +1", systemImage: "plus")
            }
            Button("Bearbeiten") {
                showingEdit = true
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                EpisodeEditView(episode: episode)
            }
        }
    }
}

/// A simple flow layout that wraps items to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
