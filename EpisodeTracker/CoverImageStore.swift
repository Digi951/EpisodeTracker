import UIKit

struct CoverImageStore {
    private let coverDirectory: URL
    private let maxDimension: CGFloat = 512
    private let compressionQuality: CGFloat = 0.8

    init(baseDirectory: URL? = nil) {
        if let base = baseDirectory {
            coverDirectory = base
        } else {
            guard let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            else {
                fatalError("Application Support directory unavailable")
            }
            coverDirectory = appSupport
                .appendingPathComponent("EpisodeTracker", isDirectory: true)
                .appendingPathComponent("covers", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: coverDirectory,
            withIntermediateDirectories: true
        )
    }

    func save(_ image: UIImage, name: String) throws {
        guard Self.isValidCoverName(name) else {
            throw CoverImageStoreError.invalidName
        }

        let scaled = scaled(image)
        guard let data = scaled.jpegData(compressionQuality: compressionQuality) else {
            throw CoverImageStoreError.compressionFailed
        }
        let url = fileURL(for: name)
        try data.write(to: url, options: [.atomic])
    }

    func load(name: String) -> UIImage? {
        guard Self.isValidCoverName(name) else { return nil }

        let url = fileURL(for: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func exists(name: String) -> Bool {
        guard Self.isValidCoverName(name) else { return false }

        return FileManager.default.fileExists(atPath: fileURL(for: name).path)
    }

    func delete(name: String) throws {
        guard Self.isValidCoverName(name) else { return }

        let url = fileURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    static func coverName(for episodeID: UUID) -> String {
        episodeID.uuidString
    }

    private func fileURL(for name: String) -> URL {
        coverDirectory.appendingPathComponent("\(name).jpg")
    }

    private static func isValidCoverName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == name else { return false }
        guard !name.contains("/") && !name.contains("\\") else { return false }
        guard name != "." && name != ".." else { return false }
        return true
    }

    private func scaled(_ image: UIImage) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale: CGFloat
        if size.width >= size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }

        let targetSize = CGSize(
            width: (size.width * scale).rounded(.down),
            height: (size.height * scale).rounded(.down)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

enum CoverImageStoreError: LocalizedError {
    case invalidName
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Cover image name is invalid."
        case .compressionFailed:
            return "Cover image could not be compressed to JPEG."
        }
    }
}
