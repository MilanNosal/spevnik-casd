import SwiftData
import SwiftUI
import SwiftUIPager

struct SongsView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(FetchDescriptor<Song>(predicate: nil,
                                 sortBy: [SortDescriptor<Song>(\.number)]),
           animation: .spring(duration: 0.25))
    private var songs: [Song]
    
    @ObservedObject var page: Page
    
    var body: some View {
        VStack {
            Pager(page: page, data: songs, id: \.number) { song in
                SongView(song: song)
            }
            .pagingPriority(.simultaneous)
            .expandPageToEdges()
            .delaysTouches(true)
            .loopPages()
            .draggingAnimation(.interactive)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if songs.indices.contains(page.index) {
                    let song = songs[page.index]
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(song.formattedNumber())").bold().monospaced().opacity(0.8)
                        Text(song.title)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Song {
    func formattedNumber() -> String {
        String(format: "%3d", number)
    }
}
