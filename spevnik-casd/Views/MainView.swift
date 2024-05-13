import SwiftUI
import SwiftData
import SwiftUIPager

struct MainView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(FetchDescriptor<Song>(predicate: nil,
                                 sortBy: [SortDescriptor<Song>(\.number)]),
           animation: .spring(duration: 0.25))
    private var songs: [Song]
    
    @State private var isShowingSongDetail = false
    @State private var isShowingSettings = false
    @StateObject private var page: Page = .first()

    var body: some View {
        VStack {
            if !songs.isEmpty {
                ScrollView {
                    LazyVStack {
                        ForEach(songs) { song in
                            row(song: song)
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }
            } else {
                ProgressView()
                .scaleEffect(1.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .frame(width: 44, height: 44)
                .tint(colorScheme == .dark ? Color.white : Color.black)
            }
            
            ToolbarItem(placement: .principal) {
                Text("Spievajme Hospodinovi")
                    .bold()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background {
            navigationLinks()
        }
    }
    
    @ViewBuilder
    private func navigationLinks() -> some View {
        Spacer()
            .navigationDestination(isPresented: $isShowingSettings, destination: {
                SettingsView()
            })
            .navigationDestination(isPresented: $isShowingSongDetail, destination: {
                SongsView(page: page)
            })
    }
    
    @ViewBuilder
    private func row(song: Song) -> some View {
        Button {
            guard let index = songs.firstIndex(of: song) else { return }
            withAnimation(.none) {
                page.update(.new(index: index))
            }
            isShowingSongDetail = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("\(song.formattedNumber())").bold().monospaced().opacity(0.8)
                    .layoutPriority(1)
                
                Text(song.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 8))
        }
        .tint(colorScheme == .dark ? Color.white : Color.black)
    }
}
