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

    @ViewBuilder
    private var numberSlotContent: some View {
        if episode.isSpecial {
            Image(systemName: "sparkles")
        } else {
            Text("\(episode.episodeNumber)")
        }
    }

    // Favoriten-Markierung im Zahlenslot statt als Cover-Badge: gefüllter
    // Akzent-Kreis mit Mini-Herz oben rechts. Das Lesezeichen erscheint
    // bewusst nur noch in der Detailansicht.
    @ViewBuilder
    private var numberSlot: some View {
        let slotWidth: CGFloat = isInSidebar ? 26 : 40
        if episode.isFavorite {
            let circleSize: CGFloat = isInSidebar ? 24 : 30
            numberSlotContent
                .font(.footnote.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(width: circleSize, height: circleSize)
                .background(appAccentColor.color, in: Circle())
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(appAccentColor.color)
                        .padding(2)
                        .background(.background, in: Circle())
                        .offset(x: 3, y: -3)
                }
                .frame(width: slotWidth, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(episode.isSpecial ? "Sonderfolge, Favorit" : "Folge \(episode.episodeNumber), Favorit"))
        } else if episode.isSpecial {
            numberSlotContent
                .font(.headline)
                .foregroundStyle(appAccentColor.color)
                .frame(width: slotWidth, alignment: .center)
                .accessibilityLabel(Text("Sonderfolge"))
        } else {
            numberSlotContent
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: slotWidth, alignment: .center)
        }
    }

    var body: some View {
        HStack(spacing: isInSidebar ? 8 : 12) {
            numberSlot

            if let coverName = episode.coverImageName, !coverName.isEmpty {
                CoverImageThumbnailView(name: coverName, updatedAt: episode.coverUpdatedAt)
            } else if anyEpisodeHasCover {
                Text(collectionInitial)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(appAccentColor.color)
                    .frame(width: 44, height: 44)
                    .background(appAccentColor.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
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

            if episode.isListened {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }
}

#if DEBUG
#Preview("EpisodeRowView – Favorit im Zahlenslot") {
    List {
        EpisodeRowView(
            episode: Episode(episodeNumber: 4, title: "Gefahr im Fitnessstudio", releaseYear: 2020, isFavorite: true, isBookmarked: true),
            anyEpisodeHasCover: true
        )
        EpisodeRowView(
            episode: Episode(episodeNumber: 240, title: "Dreistellige Folgennummer als Favorit", releaseYear: 2024, isFavorite: true),
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
