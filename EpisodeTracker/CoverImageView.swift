import SwiftUI

struct CoverImageView: View {
    let name: String
    var maxHeight: CGFloat = 200
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                coverImage(image)
            }
        }
        .onAppear { loadImage(named: name) }
        .onChange(of: name) { _, newName in loadImage(named: newName) }
    }

    private func coverImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func loadImage(named name: String) {
        image = CoverImageCache.shared.image(named: name)
    }
}

struct CoverImageThumbnailView: View {
    let name: String
    var size: CGFloat = 44
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                thumbnail(image)
            }
        }
        .onAppear { loadImage(named: name) }
        .onChange(of: name) { _, newName in loadImage(named: newName) }
    }

    private func thumbnail(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func loadImage(named name: String) {
        image = CoverImageCache.shared.image(named: name)
    }
}
