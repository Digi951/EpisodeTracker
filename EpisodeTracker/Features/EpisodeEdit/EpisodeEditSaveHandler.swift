// EpisodeTracker/Features/EpisodeEdit/EpisodeEditSaveHandler.swift
import Foundation
import SwiftData

enum EpisodeSaveOutcome: Equatable {
    case saved
    case duplicateNumber
    case saveFailed
    case invalidInput
}

enum EpisodeEditSaveHandler {
    /// Persistiert den Draft als neue oder bestehende Folge.
    /// Die Freemium-Schranke wird bewusst NICHT hier geprüft — das passiert
    /// in der View vor dem Aufruf (braucht Query-Count und AppStorage).
    static func save(
        draft: EpisodeEditDraft,
        existingEpisode: Episode?,
        existingEpisodes: [Episode],
        coverChange: EpisodeCoverChange,
        in context: ModelContext
    ) -> EpisodeSaveOutcome {
        guard let episodeNumber = draft.parsedEpisodeNumber,
              let releaseYear = draft.parsedReleaseYear,
              let selectedUniverse = draft.selectedUniverse else {
            return .invalidInput
        }

        if hasDuplicateEpisodeNumber(
            in: selectedUniverse,
            episodeNumber: episodeNumber,
            existingEpisodes: existingEpisodes,
            editingEpisode: existingEpisode
        ) {
            return .duplicateNumber
        }

        if let episode = existingEpisode {
            let wasListened = episode.isListened
            let previousMoodKeys = Set(episode.moods.map(\.resolvedSyncKey))
            let newMoodKeys = Set(draft.selectedMoods.map(\.resolvedSyncKey))
            let previousNote = episode.personalNote
            let previousRating = episode.rating
            let previousStreamingURL = episode.streamingURL
            let previousListenStatus = episode.isListened
            episode.episodeNumber = episodeNumber
            episode.title = draft.title
            episode.releaseYear = releaseYear
            episode.personalNote = draft.personalNote.isEmpty ? nil : draft.personalNote
            episode.isListened = draft.isListened
            episode.rating = draft.rating
            episode.universe = selectedUniverse
            episode.moods = Array(draft.selectedMoods)
            if previousMoodKeys != newMoodKeys {
                episode.moodsUpdatedAt = .now
            }
            episode.streamingURL = draft.streamingURL.isEmpty ? nil : draft.streamingURL
            if episode.personalNote != previousNote { episode.noteUpdatedAt = .now }
            if episode.rating != previousRating { episode.ratingUpdatedAt = .now }
            if episode.streamingURL != previousStreamingURL { episode.streamingURLUpdatedAt = .now }
            if episode.isListened != previousListenStatus { episode.listenStatusUpdatedAt = .now }
            if episode.isHidden != draft.isHidden {
                episode.isHidden = draft.isHidden
                episode.hiddenUpdatedAt = .now
            }
            episode.refreshSyncKeyIfPossible()
            applyCover(coverChange, to: episode)

            if draft.isListened && !wasListened {
                episode.listenCount += 1
                episode.lastListenedAt = .now
                if episode.isBookmarked {
                    episode.isBookmarked = false
                    episode.bookmarkedUpdatedAt = .now
                }
            }
        } else {
            let newEpisode = Episode(
                episodeNumber: episodeNumber,
                title: draft.title,
                releaseYear: releaseYear,
                personalNote: draft.personalNote.isEmpty ? nil : draft.personalNote,
                isListened: draft.isListened,
                rating: draft.rating,
                universe: selectedUniverse,
                moods: Array(draft.selectedMoods)
            )
            newEpisode.streamingURL = draft.streamingURL.isEmpty ? nil : draft.streamingURL
            if !draft.selectedMoods.isEmpty {
                newEpisode.moodsUpdatedAt = .now
            }
            if draft.isListened {
                newEpisode.listenCount = 1
                newEpisode.lastListenedAt = .now
            }
            applyCover(coverChange, to: newEpisode)
            context.insert(newEpisode)
        }

        do {
            try context.save()
            return .saved
        } catch {
            return .saveFailed
        }
    }

    private static func applyCover(_ change: EpisodeCoverChange, to episode: Episode) {
        try? EpisodeCoverManager().apply(change, to: episode)
    }

    private static func hasDuplicateEpisodeNumber(
        in universe: Universe,
        episodeNumber: Int,
        existingEpisodes: [Episode],
        editingEpisode: Episode?
    ) -> Bool {
        existingEpisodes.contains { candidate in
            guard candidate.episodeNumber == episodeNumber else { return false }
            guard candidate.universe?.id == universe.id else { return false }
            if let editingEpisode {
                return candidate.id != editingEpisode.id
            }
            return true
        }
    }
}
