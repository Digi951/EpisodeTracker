import SwiftUI

/// Breite der Nummernspalte für alle Zeilen einer Liste: so viele Stellen wie
/// die längste Nummer, mindestens Platz für Favoritenkreis oder ✨, wenn einer
/// vorkommt. Listen ohne Angabe rechnen mit drei Stellen und Kreis.
struct EpisodeNumberColumn: Equatable {
    var digits = 3
    var hasBadge = true

    init() {}

    init(episodes: [Episode]) {
        digits = String(episodes.map(\.episodeNumber).max() ?? 1).count
        hasBadge = episodes.contains { $0.isFavorite || $0.showsSpecialBadge }
    }
}

private struct EpisodeNumberColumnKey: EnvironmentKey {
    static let defaultValue = EpisodeNumberColumn()
}

extension EnvironmentValues {
    var episodeNumberColumn: EpisodeNumberColumn {
        get { self[EpisodeNumberColumnKey.self] }
        set { self[EpisodeNumberColumnKey.self] = newValue }
    }
}

struct EpisodeRowView: View {
    let episode: Episode
    let anyEpisodeHasCover: Bool
    var isInSidebar: Bool = false
    /// Steht die Zeile unter der Überschrift ihrer Reihe, wiederholt der
    /// Reihenname vorne am Titel nur die Überschrift und wird gekürzt.
    var omitsSeriesPrefix: Bool = false
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    @Environment(\.episodeNumberColumn) private var numberColumn
    @Environment(\.editMode) private var editMode
    @ScaledMetric(relativeTo: .headline) private var digitWidth: CGFloat = 10.5
    @ScaledMetric(relativeTo: .headline) private var badgeWidth: CGFloat = 30

    /// Nicht breiter als nötig: Jeder Punkt hier fehlt dem Titel.
    private var numberSlotWidth: CGFloat {
        max(CGFloat(numberColumn.digits) * digitWidth, numberColumn.hasBadge ? badgeWidth : 0)
    }

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

    private var displayTitle: String {
        guard omitsSeriesPrefix, let universe = episode.universe else { return episode.title }
        return EpisodeListOrganizer.titleOmittingSeriesPrefix(
            episode.title,
            seriesNames: [universe.name, AppLocalization.displayName(forUniverseName: universe.name)]
        )
    }

    private var collectionInitial: String {
        let name = episode.universe?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    /// Wortwahl für den Nummernslot: "Sonderfolge" ist nur in einer nummerierten
    /// Reihe eine sinnvolle Ausnahme-Bezeichnung. In einem Anthologie-Katalog
    /// (jede Folge ist `.special`, aber ohne Reihen-Nummer) fällt die Bezeichnung
    /// auf den Folgentitel zurück statt eine bedeutungslose Nummer zu zeigen.
    private var specialAccessibilityLabel: String {
        episode.showsSpecialBadge ? "Sonderfolge" : episode.title
    }

    @ViewBuilder
    private var numberSlotContent: some View {
        if episode.showsSpecialBadge {
            Image(systemName: "sparkles")
        } else if (episode.universe?.style ?? .numbered).usesEpisodeNumbers {
            Text("\(episode.episodeNumber)")
        } else {
            // Anthologie-Folge: weder eine sinnvolle Nummer noch eine Ausnahme,
            // also auch kein Sparkles-Badge, das "Sonderfolge" suggerieren würde.
            EmptyView()
        }
    }

    // Favoriten-Markierung im Zahlenslot statt als Cover-Badge: gefüllter
    // Akzent-Kreis mit Mini-Herz oben rechts. Das Lesezeichen erscheint
    // bewusst nur noch in der Detailansicht.
    @ViewBuilder
    private var numberSlot: some View {
        let slotWidth: CGFloat = isInSidebar ? 26 : numberSlotWidth
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
                .frame(width: slotWidth, alignment: .trailing)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(episode.isSpecial ? "\(specialAccessibilityLabel), Favorit" : "Folge \(episode.episodeNumber), Favorit"))
        } else if episode.showsSpecialBadge {
            numberSlotContent
                .font(.headline)
                .foregroundStyle(appAccentColor.color)
                .frame(width: slotWidth, alignment: .trailing)
                .accessibilityLabel(Text(specialAccessibilityLabel))
        } else {
            numberSlotContent
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Rechtsbündig wie eine Nummernspalte: 1 und 240 stehen untereinander.
                .frame(width: slotWidth, alignment: .trailing)
        }
    }

    var body: some View {
        HStack(spacing: isInSidebar ? 8 : 13) {
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
                // Normale Schriftstärke für alle Titel; gehörte Folgen treten
                // über die Farbe zurück, damit offene auffallen, ohne dass
                // eine überwiegend offene Liste komplett fett wird.
                Text(displayTitle)
                    .font(.body)
                    .foregroundStyle(episode.isListened ? .secondary : .primary)
                    .lineLimit(isInSidebar ? 2 : 1)
                    .accessibilityLabel(Text(episode.title))

                if let notePreview {
                    Text(notePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if !episode.moods.isEmpty {
                        Text(episode.moods.compactMap(\.iconName).joined())
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if let rating = episode.rating {
                        // Kompakt statt fünf Sterne: leere Sterne sind nur Rauschen.
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("\(rating)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(AppLocalization.format(
                            "EpisodeRow.RatingAccessibility",
                            defaultValue: "Bewertung %lld von 5",
                            Int64(rating)
                        )))
                    }
                    // Sonderfolgen-Markierung: Das ✨-Icon im Nummernslot reicht;
                    // die Detailansicht zeigt "Sonderfolge" als Titel.
                }
            }
            .layoutPriority(1)
            // Trennlinie ab dem Titel, sonst springt sie mit der Stellenzahl.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            // Ohne Mindestbreite: Der Titel darf bis an Häkchen oder Pille reichen.
            Spacer(minLength: 0)

            if episode.isListened {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Gehört"))
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else {
                Text("Offen")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.12), in: Capsule())
                    // Die Pille behält ihre Breite; gekürzt wird der Titel.
                    .fixedSize()
                    .layoutPriority(2)
                    .transition(.opacity)
            }
        }
        // Der Standard-Zeileneinzug (20 pt) ist links doppelt so breit wie der
        // Abstand zum Cover; so steht die Nummer mittig zwischen Rand und Cover.
        // Im Auswahlmodus steht der Auswahlkreis davor, dort kein Versatz.
        .padding(.leading, isInSidebar || editMode?.wrappedValue.isEditing == true ? 0 : -7)
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
