import Foundation

/// Die eine konkrete Empfehlung oben in „Als nächstes“: beantwortet „Was höre
/// ich jetzt?“, statt nur Listen anzubieten (Design Review 2026-11, Befund 4;
/// ursprüngliche Idee in der Vault-Notiz „Als nächstes hören“).
struct UpNextRecommendation {
    enum Reason: Equatable {
        /// Nächste ungehörte Folge einer Reihe, in der zuletzt gehört wurde.
        case continueSeries
        /// Vom Nutzer selbst auf die Merkliste gesetzt.
        case bookmarked
        /// Rückfall: irgendeine offene Folge der Bibliothek.
        case open

        var label: String {
            switch self {
            case .continueSeries:
                String(localized: "UpNext.Recommendation.ContinueSeries", defaultValue: "Nächste offene Folge")
            case .bookmarked:
                String(localized: "UpNext.Recommendation.Bookmarked", defaultValue: "Auf deiner Merkliste")
            case .open:
                String(localized: "UpNext.Recommendation.Open", defaultValue: "Noch nicht gehört")
            }
        }
    }

    let episode: Episode
    let reason: Reason

    /// Kandidaten in Vorschlagsreihenfolge, ohne Dubletten. „Anderer
    /// Vorschlag“ blättert durch diese Liste.
    static func candidates(from episodes: [Episode]) -> [UpNextRecommendation] {
        var seen = Set<ObjectIdentifier>()
        var result: [UpNextRecommendation] = []

        func append(_ list: [Episode], reason: Reason) {
            for episode in list where seen.insert(ObjectIdentifier(episode)).inserted {
                result.append(UpNextRecommendation(episode: episode, reason: reason))
            }
        }

        append(SmartListDefinition.continuationEpisodes(from: episodes), reason: .continueSeries)
        append(SmartListDefinition.laterListenEpisodes(from: episodes), reason: .bookmarked)
        append(
            episodes
                .filter { !$0.isHidden && !$0.isListened }
                .sorted {
                    let name0 = $0.universe?.name ?? ""
                    let name1 = $1.universe?.name ?? ""
                    if name0 != name1 {
                        return name0.localizedCompare(name1) == .orderedAscending
                    }
                    return $0.episodeNumber < $1.episodeNumber
                },
            reason: .open
        )
        return result
    }
}
