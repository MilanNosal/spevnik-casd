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

    @Query(sort: \UserTag.name)
    private var userTags: [UserTag]

    @Query(sort: \BuiltInTag.name)
    private var builtInTags: [BuiltInTag]

    @State private var isShowingSongDetail = false
    @State private var isShowingSettings = false
    @State private var isShowingFilter = false
    @State private var searchText = ""
    @State private var selectedTags: Set<TagID> = []
    @StateObject private var page: Page = .first()

    /// Built-in tag names from the precomputed catalog.
    private var builtInTagNames: [String] {
        builtInTags.map(\.name)
    }

    private var userTagNames: [String] {
        userTags.map(\.name)
    }

    /// Selected tags that still correspond to an available tag. Guards against a
    /// stale selection (e.g. a built-in tag removed by a re-seed) silently
    /// filtering the list down to nothing.
    private var activeTags: Set<TagID> {
        let available: Set<TagID> =
            Set(builtInTagNames.map { TagID(kind: .builtIn, name: $0) })
            .union(userTagNames.map { TagID(kind: .user, name: $0) })
        return selectedTags.intersection(available)
    }

    private var filteredSongs: [Song] {
        var result = songs

        let query = searchText
            .folding(options: .diacriticInsensitive, locale: Locale.current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { $0.searchableCacheString.contains(query) }
        }

        let tags = activeTags
        if !tags.isEmpty {
            // Resolve the required tags once, up front, so the per-song filter is
            // pure set/array membership: built-in names to match, and user-tag
            // song-number sets for O(1) membership instead of scanning arrays.
            let requiredBuiltIn = tags.filter { $0.kind == .builtIn }.map(\.name)
            let requiredUserSets: [Set<Int>] = tags
                .filter { $0.kind == .user }
                .map { tag in
                    userTags.first { $0.name == tag.name }.map { Set($0.songNumbers) } ?? []
                }

            result = result.filter { song in
                requiredBuiltIn.allSatisfy(song.matchesBuiltIn)
                    && requiredUserSets.allSatisfy { $0.contains(song.number) }
            }
        }

        return result
    }

    var body: some View {
        VStack {
            if songs.isEmpty {
                ProgressView()
                    .scaleEffect(1.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if filteredSongs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(filteredSongs) { song in
                            row(song: song)
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Hľadať")
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

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingFilter = true
                } label: {
                    Image(systemName: activeTags.isEmpty
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
                .frame(width: 44, height: 44)
                .tint(activeTags.isEmpty
                      ? (colorScheme == .dark ? Color.white : Color.black)
                      : Color.green)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingFilter) {
            TagFilterView(builtInTags: builtInTagNames,
                          userTags: userTagNames,
                          selectedTags: $selectedTags)
        }
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
                SongsView(songs: filteredSongs, page: page)
            })
    }
    
    @ViewBuilder
    private func row(song: Song) -> some View {
        Button {
            guard let index = filteredSongs.firstIndex(of: song) else { return }
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
