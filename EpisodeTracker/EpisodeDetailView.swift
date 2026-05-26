import SwiftUI

struct EpisodeDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("preferredStreamingService") private var preferredServiceRaw = StreamingService.spotify.rawValue
    let episode: Episode
    @State private var catalog = EpisodeCatalog.shared
    @State private var showingEdit = false
    @State private var heroCoverImage: UIImage?
    @State private var heroCoverTint = Color.pink

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

    private var listenActionColor: Color {
        episode.isListened ? .accentColor : .green
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DetailMetrics.heroToPanel) {
                if let coverName = episode.coverImageName, !coverName.isEmpty {
                    heroCover(coverName: coverName)
                }
                contentPanel
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.top, scrollTopPadding)
            .padding(.bottom, DetailMetrics.scrollBottom)
        }
        .navigationTitle("Folge \(episode.episodeNumber)")
        .background(fullScreenCoverBackground)
        .toolbar {
            Button("Bearbeiten") {
                showingEdit = true
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                EpisodeEditView(episode: episode)
            }
        }
        .onAppear { loadHeroCover(named: episode.coverImageName) }
        .onChange(of: episode.coverImageName) { _, newName in
            loadHeroCover(named: newName)
        }
    }

    // MARK: - Hero cover

    private func heroCover(coverName: String) -> some View {
        CoverImageView(name: coverName, maxHeight: coverMaxHeight)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Continuous glass panel

    private var contentPanel: some View {
        VStack(spacing: 0) {
            infoBlock

            if !episode.moods.isEmpty {
                panelDivider
                moodsBlock
            }

            if let streamingLink = resolvedStreamingLink {
                panelDivider
                streamingBlock(streamingLink)
            }

            if let note = episode.personalNote, !note.isEmpty {
                panelDivider
                noteBlock(note)
            }
        }
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(heroCoverTint.opacity(heroCoverImage == nil ? 0 : 0.07))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DetailMetrics.panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DetailMetrics.panelCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 6)
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: DetailMetrics.intraBlock) {
            // Katalog + Jahr
            Text("\(AppLocalization.displayName(forUniverseName: episode.universe?.name)) · \(String(episode.releaseYear))")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.62))

            // Titel
            Text(episode.title)
                .font(.title2.weight(.bold))

            // Status + Rating Zeile
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statusBadge
                    ratingStars
                    Spacer(minLength: 0)
                    listenAgainButton
                }

                HStack(spacing: 10) {
                    statusBadge
                    ratingStars
                    Spacer(minLength: 0)
                    compactListenAgainButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        statusBadge
                        compactListenAgainButton
                    }
                    ratingStars
                }
            }

            if let lastListened = episode.lastListenedAt {
                Text("Zuletzt gehört: \(lastListened.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DetailMetrics.blockPadding)
    }

    private var statusBadge: some View {
        Label(statusLabel, systemImage: episode.isListened ? "checkmark.circle.fill" : "circle")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12), in: .capsule)
    }

    private var ratingStars: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= (episode.rating ?? 0) ? "star.fill" : "star")
                    .font(.subheadline)
                    .foregroundStyle(star <= (episode.rating ?? 0) ? .yellow : .gray.opacity(0.4))
            }
        }
    }

    private var listenAgainButton: some View {
        Button(action: recordListen) {
            Label(
                episode.isListened ? "Nochmal" : "Gehört",
                systemImage: episode.isListened ? "arrow.counterclockwise" : "ear"
            )
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(listenActionColor)
    }

    private var compactListenAgainButton: some View {
        Button(action: recordListen) {
            Image(systemName: episode.isListened ? "arrow.counterclockwise" : "ear")
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(listenActionColor)
        .accessibilityLabel(episode.isListened ? "Nochmal hören" : "Als gehört markieren")
    }

    private func recordListen() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            episode.isListened = true
            episode.listenCount += 1
            episode.lastListenedAt = .now
            episode.listenStatusUpdatedAt = .now
        }
    }

    private var moodsBlock: some View {
        VStack(alignment: .leading, spacing: DetailMetrics.intraBlock) {
            Text("Stimmungen")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.62))

            FlowLayout(spacing: 8) {
                ForEach(episode.moods) { mood in
                    Text("\(mood.iconName ?? "") \(mood.name)")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.fill.tertiary.opacity(0.84), in: .capsule)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DetailMetrics.blockPadding)
    }

    private func streamingBlock(_ link: (url: URL, label: String)) -> some View {
        Link(destination: link.url) {
            Label(link.label, systemImage: streamingService.iconName)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DetailMetrics.blockPadding)
                .contentShape(Rectangle())
        }
    }

    private func noteBlock(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: DetailMetrics.intraBlock) {
            Text("Persönliche Notiz")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.62))

            Text(note)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DetailMetrics.blockPadding)
    }

    // MARK: - Background

    @ViewBuilder
    private var fullScreenCoverBackground: some View {
        if let heroCoverImage {
            ZStack {
                Image(uiImage: heroCoverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.12)
                    .blur(radius: 56)
                    .opacity(0.72)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground).opacity(0.45),
                        Color(.systemGroupedBackground).opacity(0.34),
                        Color(.systemGroupedBackground).opacity(0.66)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        } else {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }

    // MARK: - Metrics

    private enum DetailMetrics {
        static let heroToPanel: CGFloat = 20
        static let panelCornerRadius: CGFloat = 24
        static let blockPadding: CGFloat = 18
        static let intraBlock: CGFloat = 12
        static let scrollBottom: CGFloat = 28
    }

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 640 : .infinity
    }

    private var scrollTopPadding: CGFloat {
        horizontalSizeClass == .regular ? 12 : 8
    }

    private var coverMaxHeight: CGFloat {
        640
    }

    // MARK: - Cover loading

    private func loadHeroCover(named name: String?) {
        guard let name, !name.isEmpty else {
            heroCoverImage = nil
            heroCoverTint = .pink
            return
        }

        let image = CoverImageCache.shared.image(named: name)
        heroCoverImage = image
        heroCoverTint = image?.vibrantAverageColor.map(Color.init(uiColor:)) ?? .pink
    }
}

private extension UIImage {
    var vibrantAverageColor: UIColor? {
        guard let cgImage else { return nil }

        let width = 24
        let height = 24
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var totalWeight: CGFloat = 0

        for index in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = CGFloat(pixelData[index]) / 255
            let g = CGFloat(pixelData[index + 1]) / 255
            let b = CGFloat(pixelData[index + 2]) / 255
            let maxChannel = max(r, g, b)
            let minChannel = min(r, g, b)
            let saturation = maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel

            guard saturation > 0.28, maxChannel > 0.22 else { continue }

            let weight = saturation * maxChannel
            red += r * weight
            green += g * weight
            blue += b * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }

        let averageColor = UIColor(
            red: red / totalWeight,
            green: green / totalWeight,
            blue: blue / totalWeight,
            alpha: 1
        )

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard averageColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return averageColor
        }

        return UIColor(
            hue: hue,
            saturation: max(saturation, 0.58),
            brightness: min(max(brightness, 0.46), 0.82),
            alpha: 1
        )
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
