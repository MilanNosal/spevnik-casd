import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.identifier, category: "SongBook")

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

    @State private var loadFailed = false
    @State private var sheetStore = SheetStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainView()
            }
            .environment(sheetStore)
            .task {
                updateSongBookIfNewUpdate()
            }
            .alert("Nepodarilo sa načítať spevník", isPresented: $loadFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Prosím, skúste aplikáciu reštartovať. Ak problém pretrváva, kontaktujte nás na milan.nosal@gmail.com.")
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
            logger.error("Failed to parse songs from bundled archive")
            loadFailed = true
            return
        }

        var currentSongs: FetchDescriptor<Song> = FetchDescriptor<Song>(
            predicate: nil,
            sortBy: [SortDescriptor<Song>(\.number)]
        )
        currentSongs.fetchLimit = nil
        currentSongs.includePendingChanges = true

        let context = sharedModelContainer.mainContext
        let results: [Song]
        do {
            results = try context.fetch(currentSongs)
        } catch {
            logger.error("Failed to fetch existing songs: \(error, privacy: .public)")
            loadFailed = true
            return
        }
        let resultsAsHash = Dictionary(results.map({ ($0.number, $0) }), uniquingKeysWith: { a, b in a })
        let incomingNumbers = Set(songs.map(\.number))
        for song in songs {
            if let result = resultsAsHash[song.number] {
                result.update(from: song)
            } else {
                context.insert(Song(from: song))
            }
        }
        // Remove songs that are no longer present in the bundled archive.
        for result in results where !incomingNumbers.contains(result.number) {
            context.delete(result)
        }

        songBookVersion = Bundle.main.appBuild
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
                  searchableCacheString: songStub.songTextDiacriticsInsensitive(),
                  sheets: songStub.sheets)
    }

    func update(from songStub: SongStub) {
        var verses: [SongVerse] = []
        for (index, verseStub) in songStub.verses.enumerated() {
            verses.append(SongVerse(orderIndex: index, number: verseStub.number, lines: verseStub.lines))
        }
        self.title = songStub.title
        self.verses = verses
        self.searchableCacheString = songStub.songTextDiacriticsInsensitive()
        self.sheets = songStub.sheets
    }
}
