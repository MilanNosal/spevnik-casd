import SwiftUI

struct SheetMusicView: View {

    let title: String
    let sheetNames: [String]

    @Environment(SheetStore.self) private var sheetStore
    @Environment(\.dismiss) private var dismiss

    private var availableURLs: [URL] {
        sheetNames.compactMap { sheetStore.imageURL(for: $0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                let urls = availableURLs
                if urls.isEmpty {
                    ContentUnavailableView("Noty nie sú k dispozícii",
                                           systemImage: "music.note.list")
                } else {
                    TabView {
                        ForEach(urls, id: \.self) { url in
                            ZoomableImage(url: url)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
                    .background(Color.black.opacity(0.02))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hotovo") { dismiss() }
                }
            }
        }
    }
}

/// A single sheet image that can be pinch-zoomed and panned.
private struct ZoomableImage: View {

    let url: URL

    @State private var image: UIImage?
    @State private var didFail = false

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale <= 1 { withAnimation { resetPan() } }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                offset = CGSize(width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height)
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if scale > 1 { scale = 1; lastScale = 1; resetPan() }
                            else { scale = 2.5; lastScale = 2.5 }
                        }
                    }
            } else if didFail {
                ContentUnavailableView("Obrázok sa nepodarilo načítať",
                                       systemImage: "exclamationmark.triangle")
            } else {
                ProgressView()
            }
        }
        // Load and decode off the main actor. `.task(id:)` re-runs when the page's
        // URL changes and cancels the prior load as `TabView` reuses the view.
        .task(id: url) {
            image = nil
            didFail = false
            let loaded = await Self.loadImage(at: url)
            guard !Task.isCancelled else { return }
            if let loaded { image = loaded } else { didFail = true }
        }
    }

    /// Loads and fully decodes the image off the main thread. `UIImage(contentsOfFile:)`
    /// defers decoding to first draw, so we force it here by re-drawing into a
    /// bitmap. (Using `preparingForDisplay()` instead routes through an ImageIO
    /// path that logs a benign "-17102 decompressing image -- possibly corrupt"
    /// for some of these PNGs; redrawing decodes cleanly without the noise.)
    private static func loadImage(at url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            let format = UIGraphicsImageRendererFormat.preferred()
            format.scale = image.scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            return renderer.image { _ in
                image.draw(at: .zero)
            }
        }.value
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}
