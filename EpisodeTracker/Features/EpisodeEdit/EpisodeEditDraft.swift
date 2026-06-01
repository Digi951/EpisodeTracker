// EpisodeTracker/Features/EpisodeEdit/EpisodeEditDraft.swift
import Foundation

struct EpisodeEditDraft {
    var episodeNumberText: String = ""
    var title: String = ""
    var releaseYearText: String = ""
    var personalNote: String = ""
    var isListened: Bool = false
    var rating: Int?
    var selectedMoods: Set<Mood> = []
    var selectedUniverse: Universe?
    var streamingURL: String = ""
    var isHidden: Bool = false
    var isSpecial: Bool = false

    init() {}

    /// Bestehende Folge in den Formularzustand laden.
    init(episode: Episode, universes: [Universe]) {
        episodeNumberText = episode.isSpecial && episode.episodeNumber == 0
            ? ""
            : String(episode.episodeNumber)
        isSpecial = episode.isSpecial
        title = episode.title
        releaseYearText = String(episode.releaseYear)
        personalNote = episode.personalNote ?? ""
        isListened = episode.isListened
        rating = episode.rating
        streamingURL = episode.streamingURL ?? ""
        isHidden = episode.isHidden
        selectedMoods = Set(episode.moods)
        selectedUniverse = episode.universe ?? universes.first
    }

    var parsedEpisodeNumber: Int? {
        Int(episodeNumberText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var parsedReleaseYear: Int? {
        Int(releaseYearText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isComplete: Bool {
        guard !title.isEmpty, parsedReleaseYear != nil, selectedUniverse != nil else { return false }
        if isSpecial { return true }
        return parsedEpisodeNumber != nil
    }
}
