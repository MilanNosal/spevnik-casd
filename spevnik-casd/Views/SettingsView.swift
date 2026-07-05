import SwiftUI

struct SettingsView: View {

    @AppStorage("org.valesoft.casd.breakingLines") private var showLineBreaks = true

    @Environment(SheetStore.self) private var sheetStore

    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Toggle("Zalomenie riadkov", isOn: $showLineBreaks)

            Divider()

            sheetMusicSection

            VStack(alignment: .center, spacing: 2) {
                Text("milan.nosal@gmail.com").font(.footnote).bold()
                Text(Bundle.main.appName).font(.footnote).bold()
                Text("\(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))").font(.footnote)
            }
            .opacity(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var sheetMusicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Noty").font(.headline)

            switch sheetStore.state {
            case .notDownloaded:
                Text("Noty k piesňam nie sú stiahnuté (približne 45 MB)")
                    .font(.footnote).opacity(0.8)
                    
                Button("Stiahnuť noty") { sheetStore.download() }
                    .buttonStyle(.borderedProminent)

            case .downloading(let progress):
                AnimatedEllipsisText("Sťahujem noty").font(.footnote)

                DownloadProgressBar(progress: progress)

                Button("Zrušiť", role: .cancel) { sheetStore.cancel() }

            case .downloaded:
                Label("Noty sú stiahnuté", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    
                Button("Odstrániť noty", role: .destructive) { isConfirmingDelete = true }

            case .failed(let message):
                Label("Sťahovanie zlyhalo", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    
                Text(message).font(.caption2).opacity(0.7)
                    
                Button("Skúsiť znova") { sheetStore.download() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .confirmationDialog("Odstrániť stiahnuté noty?",
                            isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Odstrániť", role: .destructive) { sheetStore.delete() }
            Button("Zrušiť", role: .cancel) { }
        }
    }
}

/// A label whose text is followed by 1–3 dots that cycle every half second,
/// e.g. "Sťahujem noty." → ".." → "..." → ".". Driven by `TimelineView`, so it
/// needs no timer or state and stops when the view leaves the screen.
private struct AnimatedEllipsisText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            // Tick count → 1, 2, or 3 dots. `.now` starts the schedule, so the
            // elapsed seconds since then give a monotonically increasing tick.
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.5)
            let dots = String(repeating: ".", count: tick % 3 + 1)
            // A transparent three-dot copy fixes the layout width; the visible text
            // is drawn on top, anchored leading, so the label doesn't shift as the
            // dot count (and thus the string length) cycles each tick.
            Text(text + "...")
                .opacity(0)
                .overlay(alignment: .leading) {
                    Text(text + dots)
                        .contentTransition(.identity)
                }
        }
    }
}

/// A determinate progress bar whose fill width animates between values. The
/// built-in linear `ProgressView` doesn't reliably animate its fill via
/// `.animation(_:value:)`, so we draw two capsules and animate the width here.
private struct DownloadProgressBar: View {
    /// Download completion in 0...1.
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(.tint)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.smooth, value: progress)
            }
        }
        .frame(height: 5)
    }
}
