import SwiftUI

struct EpisodeDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("preferredStreamingService") private var preferredServiceRaw = StreamingService.spotify.rawValue
    let episode: Episode
    @State private var catalog = EpisodeCatalog.shared
    @State private var showingEdit = false

    private var streamingService: StreamingService {
        StreamingService(rawValue: preferredServiceRaw) ?? .spotify
    }

    private var resolvedStreamingLink: (url: URL, label: String)? {
        if let directURL = streamingService.directURL(from: episode.streamingURL) {
            return (directURL, "In \(streamingService.displayName) öffnen")
        }

        let catalogEntry = catalog.entry(
            for: episode.episodeNumber,
            in: episode.universe?.name
        )

        if let entry = catalogEntry, let catalogURL = streamingService.catalogURL(from: entry) {
            return (catalogURL, "In \(streamingService.displayName) öffnen")
        }

        return nil
    }

    private var statusLabel: String {
        if episode.isListened {
            episode.listenCount > 1 ? "Gehört (\(episode.listenCount)×)" : "Gehört"
        } else if episode.listenCount > 0 {
            "Nochmal"
        } else {
            "Offen"
        }
    }

    private var statusColor: Color {
        episode.isListened ? .green : (episode.listenCount > 0 ? .orange : .secondary)
    }

    var body: some View {
        List {
            if let coverName = episode.coverImageName, !coverName.isEmpty {
                Section {
                    CoverImageView(name: coverName, maxHeight: 280)
                        .frame(maxWidth: .infinity)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Katalog + Jahr
                    Text("\(episode.universe?.name ?? "Allgemein") · \(String(episode.releaseYear))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Titel
                    Text(episode.title)
                        .font(.title2.weight(.bold))

                    // Status + Rating Zeile
                    HStack(spacing: 12) {
                        Label(statusLabel, systemImage: episode.isListened ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusColor.opacity(0.12), in: .capsule)

                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= (episode.rating ?? 0) ? "star.fill" : "star")
                                    .font(.subheadline)
                                    .foregroundStyle(star <= (episode.rating ?? 0) ? .yellow : .gray.opacity(0.3))
                            }
                        }

                        Spacer()
                    }

                    if let lastListened = episode.lastListenedAt {
                        Text("Zuletzt gehört: \(lastListened.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowSeparator(.hidden)
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

            if let streamingLink = resolvedStreamingLink {
                Section {
                    Link(destination: streamingLink.url) {
                        Label(streamingLink.label, systemImage: streamingService.iconName)
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
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 48 : 0, for: .scrollContent)
        .contentMargins(.top, horizontalSizeClass == .regular ? 12 : 0, for: .scrollContent)
        .toolbar {
            Button {
                episode.isListened = true
                episode.listenCount += 1
                episode.lastListenedAt = .now
            } label: {
                Label("Hördurchgang zählen", systemImage: "plus")
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
        let proposedWidth = proposal.width
        let wrappingWidth = max(proposedWidth ?? .greatestFiniteMagnitude, 0)
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > wrappingWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            measuredWidth = max(measuredWidth, x + size.width)
            x += size.width + spacing
        }

        let finalWidth = proposedWidth.map { max($0, 0) } ?? measuredWidth
        return (positions, CGSize(width: finalWidth, height: max(0, y + rowHeight)))
    }
}
