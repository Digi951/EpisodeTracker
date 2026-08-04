// EpisodeTracker/Features/Cover/PerspectiveCropSheet.swift
import SwiftUI
import Vision

struct PerspectiveCropSheet: View {
    let image: UIImage
    var requiresConfirmation = false
    let onConfirm: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var handles: [CGPoint] = []
    @State private var activeHandleIndex: Int?
    @State private var imageRect: CGRect = .zero
    @State private var previewImage: UIImage?
    @State private var isDetecting = false
    @State private var isApplying = false
    @State private var showOverwriteConfirmation = false
    @State private var pendingResult: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topControls

                GeometryReader { geometry in
                    let rect = PerspectiveCorrector.imageRect(
                        in: geometry.size,
                        imageSize: image.size
                    )

                    ZStack {
                        Image(uiImage: previewImage ?? image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                        if handles.count == 4, previewImage == nil {
                            QuadOverlay(handles: handles, imageRect: rect)

                            ForEach(0..<4, id: \.self) { index in
                                DraggableHandle(
                                    position: handles[index],
                                    onDragChanged: { point in
                                        activeHandleIndex = index
                                        previewImage = nil
                                        handles[index] = clamp(point, to: rect)
                                    },
                                    onDragEnded: { point in
                                        activeHandleIndex = nil
                                        handles[index] = clamp(point, to: rect)
                                    }
                                )
                            }

                            if let activeHandleIndex {
                                PerspectiveLoupeView(
                                    image: image,
                                    handlePosition: handles[activeHandleIndex],
                                    imageRect: rect
                                )
                                .position(loupePosition(for: handles[activeHandleIndex], in: rect))
                                .allowsHitTesting(false)
                            }
                        }

                        if isDetecting || isApplying {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.4)
                        }
                    }
                    .coordinateSpace(name: "cropCanvas")
                    .onAppear {
                        imageRect = rect
                        initHandles(in: rect)
                    }
                    .onChange(of: geometry.size) { _, _ in
                        imageRect = rect
                        if handles.isEmpty {
                            initHandles(in: rect)
                        }
                    }
                }

                bottomControls
            }
        }
        .alert("Foto überschreiben?", isPresented: $showOverwriteConfirmation) {
            Button("Überschreiben", role: .destructive) {
                if let pendingResult {
                    onConfirm(pendingResult)
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {
                pendingResult = nil
            }
        } message: {
            Text("Das Originalfoto wird durch die perspektivkorrigierte Version ersetzt.")
        }
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            Button("Abbrechen") { dismiss() }

            Spacer(minLength: 12)

            Button("Anwenden") { applyAndConfirm() }
                .disabled(handles.count != 4 || isDetecting || isApplying)
                .fontWeight(.semibold)
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.blue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black)
    }

    private var bottomControls: some View {
        HStack(spacing: 10) {
            Button {
                previewImage = nil
                activeHandleIndex = nil
                initHandles(in: imageRect)
            } label: {
                Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
            }
            .disabled(imageRect.isEmpty || isDetecting || isApplying)

            Button {
                detectRectangle(in: imageRect)
            } label: {
                Label("Auto", systemImage: "wand.and.stars")
            }
            .disabled(imageRect.isEmpty || isDetecting || isApplying)

            Button {
                applyPreview()
            } label: {
                Label("Vorschau", systemImage: "eye")
            }
            .disabled(handles.count != 4 || isDetecting || isApplying)
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.blue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.black)
    }

    private func initHandles(in rect: CGRect) {
        let inset = min(18, rect.width * 0.04, rect.height * 0.04)
        let handleRect = rect.insetBy(dx: inset, dy: inset)
        handles = [
            CGPoint(x: handleRect.minX, y: handleRect.minY),
            CGPoint(x: handleRect.maxX, y: handleRect.minY),
            CGPoint(x: handleRect.maxX, y: handleRect.maxY),
            CGPoint(x: handleRect.minX, y: handleRect.maxY)
        ]
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func detectRectangle(in rect: CGRect) {
        let detectionImage = image.normalized()
        guard let cgImage = detectionImage.cgImage, !rect.isEmpty else { return }
        isDetecting = true

        Task { @MainActor in
            let observations = await Task.detached(priority: .userInitiated) {
                let request = VNDetectRectanglesRequest()
                request.maximumObservations = 8
                request.minimumConfidence = 0.45
                request.minimumAspectRatio = 0.2

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                return request.results ?? []
            }.value

            isDetecting = false
            let candidates = observations.map { observation in
                [
                    visionToDisplay(observation.topLeft, in: rect),
                    visionToDisplay(observation.topRight, in: rect),
                    visionToDisplay(observation.bottomRight, in: rect),
                    visionToDisplay(observation.bottomLeft, in: rect)
                ].map { clamp($0, to: rect) }
            }

            guard let detectedHandles = PerspectiveCorrector.bestDetectionCandidate(from: candidates, in: rect) else { return }
            guard isUsableQuad(detectedHandles, in: rect) else { return }
            previewImage = nil
            handles = detectedHandles
        }
    }

    private func visionToDisplay(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + (1 - point.y) * rect.height
        )
    }

    private func isUsableQuad(_ points: [CGPoint], in rect: CGRect) -> Bool {
        guard points.count == 4 else { return false }

        let polygonArea = abs(zip(points, points.dropFirst() + [points[0]]).reduce(CGFloat.zero) { area, pair in
            area + pair.0.x * pair.1.y - pair.1.x * pair.0.y
        }) / 2
        let minimumArea = rect.width * rect.height * 0.08

        return polygonArea >= minimumArea
    }


    private func ciCorners() -> [CGPoint] {
        PerspectiveCorrector.displayToCIPixels(points: handles, imageRect: imageRect, image: image)
    }

    private func applyPreview() {
        let source = image
        let corners = ciCorners()
        isApplying = true

        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                PerspectiveCorrector.apply(to: source, corners: corners)
            }.value
            previewImage = result
            isApplying = false
        }
    }

    private func applyAndConfirm() {
        let source = image
        let corners = ciCorners()
        isApplying = true

        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                PerspectiveCorrector.apply(to: source, corners: corners)
            }.value
            isApplying = false

            if requiresConfirmation {
                pendingResult = result
                showOverwriteConfirmation = true
            } else {
                onConfirm(result)
                dismiss()
            }
        }
    }

    private func loupePosition(for handle: CGPoint, in rect: CGRect) -> CGPoint {
        let isRightSide = handle.x > rect.midX
        let xOffset: CGFloat = isRightSide ? -70 : 70
        let yOffset: CGFloat = handle.y < rect.midY ? 70 : -70

        return CGPoint(x: handle.x + xOffset, y: handle.y + yOffset)
    }
}

private struct QuadOverlay: View {
    let handles: [CGPoint]
    let imageRect: CGRect

    var body: some View {
        Canvas { context, size in
            guard handles.count == 4 else { return }

            var quad = Path()
            quad.move(to: handles[0])
            quad.addLine(to: handles[1])
            quad.addLine(to: handles[2])
            quad.addLine(to: handles[3])
            quad.closeSubpath()

            var dimming = Path(imageRect)
            dimming.addPath(quad)

            context.fill(
                dimming,
                with: .color(.black.opacity(0.54)),
                style: FillStyle(eoFill: true)
            )
            context.stroke(
                quad,
                with: .color(.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct DraggableHandle: View {
    let position: CGPoint
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("cropCanvas"))
                .onChanged { onDragChanged($0.location) }
                .onEnded { onDragEnded($0.location) }
        )
    }
}

private struct PerspectiveLoupeView: View {
    let image: UIImage
    let handlePosition: CGPoint
    let imageRect: CGRect

    private let size: CGFloat = 86
    private let zoom: CGFloat = 2.2

    var body: some View {
        let localX = handlePosition.x - imageRect.minX
        let localY = handlePosition.y - imageRect.minY

        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageRect.width, height: imageRect.height)
            .scaleEffect(zoom, anchor: .topLeading)
            .offset(
                x: size / 2 - localX * zoom,
                y: size / 2 - localY * zoom
            )
            .frame(width: size, height: size, alignment: .topLeading)
            .clipped()
            .overlay(alignment: .center) {
                Crosshair()
                    .stroke(.white.opacity(0.9), lineWidth: 1)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.45), radius: 2)
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
    }
}

private struct Crosshair: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
