import SwiftUI

struct SongView: View {
    
    @AppStorage("org.valesoft.casd.breakingLines") private var showLineBreaks = true
    
    var song: Song
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(song.verses.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.hashValue) { verse in
                    verseView(verse)
                }
                
                Spacer()
            }
            .padding(EdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
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
