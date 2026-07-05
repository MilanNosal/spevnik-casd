import SwiftUI

struct SongView: View {

    @AppStorage("org.valesoft.casd.breakingLines") private var showLineBreaks = true

    @Environment(SheetStore.self) private var sheetStore

    var song: Song

    @State private var isShowingSheets = false
    @State private var isShowingTagEditor = false

    private var sortedVerses: [SongVerse] {
        song.verses.sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var hasSheets: Bool {
        song.sheets.contains { sheetStore.imageURL(for: $0) != nil }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(sortedVerses, id: \.orderIndex) { verse in
                    verseView(verse)
                }

                Spacer()
            }
            .padding(EdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                tagButton
                if hasSheets {
                    sheetButton
                }
            }
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 16))
        }
        .fullScreenCover(isPresented: $isShowingSheets) {
            SheetMusicView(title: song.title, sheetNames: song.sheets)
        }
        .sheet(isPresented: $isShowingTagEditor) {
            SongTagEditorView(song: song)
        }
    }

    private var tagButton: some View {
        Button {
            isShowingTagEditor = true
        } label: {
            Image(systemName: "tag")
                .font(.title2)
                .padding(14)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Upraviť témy")
    }

    private var sheetButton: some View {
        Button {
            isShowingSheets = true
        } label: {
            Image(systemName: "music.note.list")
                .font(.title2)
                .padding(14)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Zobraziť noty")
    }
    
    @ViewBuilder
    private func verseView(_ verse: SongVerse) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verse.formattedNumber())
                .bold()
                .monospaced()
                .opacity(0.8)
            
            Text(verse.lines.joined(separator: showLineBreaks ? "\n" : " / "))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
    }
}

extension SongVerse {
    func formattedNumber() -> String {
        String(repeating: " ", count: max(0, 3 - number.count)) + number // padded
    }
}
