import SwiftUI
import SwiftData

@main
struct spevnik_casdApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("org.valesoft.songbook.version") private var songBookVersion: String?

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView()
            }
            .task {
                updateSongBookIfNewUpdate()
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    @MainActor
    private func updateSongBookIfNewUpdate() {
        guard songBookVersion != Bundle.main.appBuild else {
            return
        }
        guard let songs = parseSongsFromArchive() else {
            // TODO: Report error
            return
        }
        
        var currentSongs: FetchDescriptor<Song> = FetchDescriptor<Song>(
            predicate: nil,
            sortBy: [SortDescriptor<Song>(\.number)]
        )
        currentSongs.fetchLimit = nil
        currentSongs.includePendingChanges = true

        let context = sharedModelContainer.mainContext
        guard let results = try? context.fetch(currentSongs) else {
            // TODO: report error
            return
        }
        let resultsAsHash = Dictionary(results.map({ ($0.number, $0) }), uniquingKeysWith: { a, b in a })
        for song in songs {
            if let result = resultsAsHash[song.number] {
                result.update(from: song)
            } else {
                context.insert(Song(from: song))
            }
        }
    }
}

extension Song {
    convenience init(from songStub: SongStub) {
        var verses: [SongVerse] = []
        for (index, verseStub) in songStub.verses.enumerated() {
            verses.append(SongVerse(orderIndex: index, number: verseStub.number, lines: verseStub.lines))
        }
        self.init(number: songStub.number,
                  title: songStub.title,
                  verses: verses,
                  searchableCacheString: songStub.songTextDiacriticsInsensitive())
    }
    
    func update(from songStub: SongStub) {
        var verses: [SongVerse] = []
        for (index, verseStub) in songStub.verses.enumerated() {
            verses.append(SongVerse(orderIndex: index, number: verseStub.number, lines: verseStub.lines))
        }
        self.title = songStub.title
        self.verses = verses
        self.searchableCacheString = songStub.songTextDiacriticsInsensitive()
    }
}
