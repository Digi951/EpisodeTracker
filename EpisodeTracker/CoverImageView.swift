import SwiftUI

struct CoverImageView: View {
    let name: String
    var maxHeight: CGFloat = 200
    private let store = CoverImageStore()

    var body: some View {
        if let image = store.load(name: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
