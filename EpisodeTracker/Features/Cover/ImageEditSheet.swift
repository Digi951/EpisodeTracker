// EpisodeTracker/Features/Cover/ImageEditSheet.swift
import SwiftUI

extension UIImage {
    func rotated(byDegrees degrees: Int) -> UIImage {
        guard degrees != 0 else { return self }
        let normalizedDegrees = ((degrees % 360) + 360) % 360
        guard normalizedDegrees != 0 else { return self }

        let radians = CGFloat(normalizedDegrees) * .pi / 180
        let newSize: CGSize
        if normalizedDegrees == 90 || normalizedDegrees == 270 {
            newSize = CGSize(width: size.height, height: size.width)
        } else {
            newSize = size
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: radians)
            draw(in: CGRect(
                x: -size.width / 2, y: -size.height / 2,
                width: size.width, height: size.height
            ))
        }
    }
}

/// Identifiable wrapper so `ImageEditSheet` can be driven via `.sheet(item:)`.
struct EditableCoverImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImageEditSheet: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentRotation: Int = 0
    @State private var perspectiveImage: UIImage?
    @State private var showPerspectiveCrop = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(uiImage: rotatedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
                HStack(spacing: 40) {
                    Button { rotate(by: -90) } label: {
                        Label("Links", systemImage: "rotate.left.fill")
                    }
                    Button { rotate(by: 90) } label: {
                        Label("Rechts", systemImage: "rotate.right.fill")
                    }
                    Button { showPerspectiveCrop = true } label: {
                        Label("Zuschneiden", systemImage: "crop.rotate")
                    }
                }
                .font(.title3)
                .labelStyle(.iconOnly)
            }
            .padding()
            .navigationTitle("Bild bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onConfirm(rotatedImage)
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPerspectiveCrop) {
            PerspectiveCropSheet(image: rotatedImage.normalized()) { correctedImage in
                perspectiveImage = correctedImage
                currentRotation = 0
            }
        }
    }

    private var workingImage: UIImage {
        perspectiveImage ?? image
    }

    private var rotatedImage: UIImage {
        workingImage.rotated(byDegrees: currentRotation)
    }

    private func rotate(by degrees: Int) {
        currentRotation = (currentRotation + degrees + 360) % 360
    }
}
