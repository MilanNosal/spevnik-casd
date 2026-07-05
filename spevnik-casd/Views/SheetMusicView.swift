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

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        if let image = UIImage(contentsOfFile: url.path) {
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
        } else {
            ContentUnavailableView("Obrázok sa nepodarilo načítať",
                                   systemImage: "exclamationmark.triangle")
        }
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }
}
