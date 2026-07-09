import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    let anyEpisodeHasCover: Bool
    var isInSidebar: Bool = false
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue

    private var notePreview: String? {
        guard let note = episode.personalNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }

        let separators = CharacterSet(charactersIn: ".!?\n")
        let first = note.components(separatedBy: separators).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (first?.isEmpty == false) ? first : note
    }

    private var appAccentColor: AppAccentColor {
        AppAccentColor.resolved(from: appAccentColorRawValue)
    }

    private var collectionInitial: String {
        let name = episode.universe?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    static func hasCoverAnchor(coverImageName: String?, anyEpisodeHasCover: Bool) -> Bool {
        coverImageName?.isEmpty == false || anyEpisodeHasCover
    }

    private var hasCoverAnchor: Bool {
        Self.hasCoverAnchor(coverImageName: episode.coverImageName, anyEpisodeHasCover: anyEpisodeHasCover)
    }

    @ViewBuilder
    private var favoriteCornerBadge: some View {
        if episode.isFavorite {
            cornerBadge(systemName: "heart.fill", color: .red)
        }
    }

    @ViewBuilder
    private var bookmarkCornerBadge: some View {
        if episode.isBookmarked {
            cornerBadge(systemName: "bookmark.fill", color: .cyan)
        }
    }

    private func cornerBadge(systemName: String, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 17, height: 17)
            .overlay(Circle().strokeBorder(.background, lineWidth: 2))
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    var body: some View {
        HStack(spacing: isInSidebar ? 8 : 12) {
            if episode.isSpecial {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(appAccentColor.color)
                    .frame(width: isInSidebar ? 26 : 40, alignment: .center)
                    .accessibilityLabel(Text("Sonderfolge"))
            } else {
                Text("\(episode.episodeNumber)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: isInSidebar ? 26 : 40, alignment: .center)
            }

            if let coverName = episode.coverImageName, !coverName.isEmpty {
                CoverImageThumbnailView(name: coverName, updatedAt: episode.coverUpdatedAt)
                    .overlay(alignment: .topTrailing) { favoriteCornerBadge }
                    .overlay(alignment: .topLeading) { bookmarkCornerBadge }
            } else if anyEpisodeHasCover {
                Text(collectionInitial)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appAccentColor.color)
                    .frame(width: 44, height: 44)
                    .background(appAccentColor.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                    .overlay(alignment: .topTrailing) { favoriteCornerBadge }
                    .overlay(alignment: .topLeading) { bookmarkCornerBadge }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(isInSidebar ? 2 : 1)

                if let notePreview {
                    Text(notePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let rating = episode.rating {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.4))
                            }
                        }
                    }
                    if !episode.moods.isEmpty {
                        Text(episode.moods.compactMap(\.iconName).joined())
                            .font(.caption)
                            .lineLimit(1)
                    }
                    // Sonderfolgen-Markierung: Das ✨-Icon im Nummernslot reicht;
                    // die Detailansicht zeigt "Sonderfolge" als Titel.
                }
            }
            .layoutPriority(1)

            Spacer()

            // Fallback ohne Cover-Anker: Bewusste Ausnahme statt erzwungener Konsistenz.
            // Ohne Cover-Box entsteht kein zusätzliches Platzproblem (kein 44pt-Element
            // verdrängt den Titel), und ein künstlicher Platzhalter-Anker würde wie ein
            // fehlendes Bild wirken. Siehe docs/superpowers/specs/2026-07-09-episode-row-badges-design.md.
            if !hasCoverAnchor && episode.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }

            if !hasCoverAnchor && episode.isBookmarked {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.cyan)
                    .font(.caption)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }

            if episode.isListened {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }
}

#if DEBUG
#Preview("EpisodeRowView – Badge-Varianten") {
    List {
        EpisodeRowView(
            episode: Episode(episodeNumber: 4, title: "Gefahr im Fitnessstudio", releaseYear: 2020, isFavorite: true, isBookmarked: true),
            anyEpisodeHasCover: true
        )
        EpisodeRowView(
            episode: Episode(episodeNumber: 1, title: "Die Handy-Falle", releaseYear: 2019),
            anyEpisodeHasCover: true
        )
        EpisodeRowView(
            episode: Episode(episodeNumber: 98, title: "Influencerin im Netz ohne Cover-Sammlung", releaseYear: 2022, isFavorite: true, isBookmarked: true),
            anyEpisodeHasCover: false
        )
    }
}
#endif
