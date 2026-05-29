// EpisodeTracker/Features/EpisodeEdit/EpisodeEditCoverHandler.swift
import SwiftUI
import PhotosUI

@MainActor
@Observable
final class EpisodeEditCoverHandler {
    var coverImage: UIImage?
    var removeCover = false
    var selectedPhotoItem: PhotosPickerItem?
    var clipboardHasImage = false

    var hasNewImage: Bool { coverImage != nil }

    /// Derives the persisted cover change from the current state.
    var coverChange: EpisodeCoverChange {
        if removeCover { return .remove }
        if let coverImage { return .replace(coverImage) }
        return .keep
    }

    func applyPickedImage(_ image: UIImage) {
        coverImage = image
        selectedPhotoItem = nil
        removeCover = false
    }

    func requestRemoval() {
        coverImage = nil
        selectedPhotoItem = nil
        removeCover = true
    }

    func refreshClipboardAvailability() {
        clipboardHasImage = UIPasteboard.general.hasImages
    }

    func pasteFromClipboard() {
        if let image = UIPasteboard.general.image {
            applyPickedImage(image)
        }
    }

    func loadPickedItem(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            coverImage = uiImage
            removeCover = false
            selectedPhotoItem = nil
        }
    }

    /// Ob für eine bestehende Folge ein sichtbares Cover existiert.
    func hasVisibleCover(for episode: Episode?) -> Bool {
        if removeCover { return false }
        if coverImage != nil { return true }
        guard let name = episode?.coverImageName, !name.isEmpty else { return false }
        return CoverImageStore().exists(name: name)
    }
}
