import SwiftUI

/// Karte mit genau einer Empfehlung oben in „Als nächstes“.
struct UpNextRecommendationCard: View {
    let recommendation: UpNextRecommendation
    let hasAlternatives: Bool
    /// Schmale iPad-Sidebar: kleineres Bild, damit der Titel Platz hat.
    var isCompact = false
    let onOpen: (() -> Void)?
    let onNext: () -> Void

    @AppStorage("preferredStreamingService") private var preferredServiceRaw = StreamingMarketProfile.current.defaultService.rawValue
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue

    private var episode: Episode { recommendation.episode }

    private var streamingService: StreamingService {
        let profile = StreamingMarketProfile.current
        guard let service = StreamingService(rawValue: preferredServiceRaw),
              profile.services.contains(service)
        else {
            return profile.defaultService
        }
        return service
    }

    private var streamingLink: (url: URL, label: String, systemImage: String)? {
        StreamingLinkResolver(service: streamingService, catalog: EpisodeCatalog.shared)
            .resolve(for: episode)
    }

    private var subtitle: String {
        let series = AppLocalization.displayName(forUniverseName: episode.universe?.name)
        if episode.showsSpecialBadge {
            return "\(series) · \(String(localized: "Sonderfolge"))"
        }
        guard (episode.universe?.style ?? .numbered).usesEpisodeNumbers else { return series }
        return "\(series) · \(String(format: NSLocalizedString("Folge %d", comment: ""), episode.episodeNumber))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 10) {
                if let streamingLink {
                    Link(destination: streamingLink.url) {
                        Label(streamingLink.label, systemImage: streamingLink.systemImage)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(action: markListened) {
                    Label("Gehört", systemImage: "checkmark")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: streamingLink == nil ? .infinity : nil)
                }
                .buttonStyle(.bordered)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            if hasAlternatives {
                Button(action: onNext) {
                    Text(String(localized: "UpNext.Recommendation.Other", defaultValue: "Anderer Vorschlag"))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var header: some View {
        let content = HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.reason.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(episode.title)
                    .font(isCompact ? .headline : .title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())

        if let onOpen {
            Button(action: onOpen) { content }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Öffnet die Folge"))
        } else {
            content
        }
    }

    @ViewBuilder
    private var artwork: some View {
        let size: CGFloat = isCompact ? 56 : 84
        if let coverName = episode.coverImageName, !coverName.isEmpty {
            CoverImageThumbnailView(name: coverName, updatedAt: episode.coverUpdatedAt, size: size)
        } else {
            let accent = AppAccentColor.resolved(from: appAccentColorRawValue).color
            Text(String(episode.universe?.name.first.map(String.init) ?? "?").uppercased())
                .font(isCompact ? .title3.weight(.semibold) : .title.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: size, height: size)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private func markListened() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            episode.isListened = true
            episode.listenCount += 1
            episode.lastListenedAt = .now
            episode.listenStatusUpdatedAt = .now
            if episode.isBookmarked {
                episode.isBookmarked = false
                episode.bookmarkedUpdatedAt = .now
            }
        }
    }
}
