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
        VStack(alignment: .leading, spacing: 12) {
            Text("Noty").font(.headline)

            switch sheetStore.state {
            case .notDownloaded:
                Text("Noty k piesňam nie sú stiahnuté (približne 45 MB)")
                    .font(.footnote).opacity(0.8)
                    
                Button("Stiahnuť noty") { sheetStore.download() }
                    .buttonStyle(.borderedProminent)

            case .downloading(let progress):
                ProgressView(value: progress) {
                    Text("Sťahujem noty...").font(.footnote)
                }
                    
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
