import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.identifier, category: "SongBook")

@main
struct spevnik_casdApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
            UserTag.self,
            BuiltInTag.self,
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
        // Remove songs that are no longer present in the bundled archive, and
        // prune their numbers from user tags so no orphaned references linger.
        let removedNumbers = Set(results.map(\.number)).subtracting(incomingNumbers)
        for result in results where removedNumbers.contains(result.number) {
            context.delete(result)
        }
        if !removedNumbers.isEmpty {
            let userTags = (try? context.fetch(FetchDescriptor<UserTag>())) ?? []
            for tag in userTags where tag.songNumbers.contains(where: removedNumbers.contains) {
                tag.songNumbers.removeAll(where: removedNumbers.contains)
            }
        }

        reconcileBuiltInTags(from: songs, in: context)

        songBookVersion = Bundle.main.appBuild
    }

    /// Rebuilds the `BuiltInTag` catalog to match the distinct set of tags in the
    /// bundled songs. Runs only during the re-seed, so the filter UI can list all
    /// built-in tags without scanning every song.
    @MainActor
    private func reconcileBuiltInTags(from songs: [SongStub], in context: ModelContext) {
        let incomingNames = Set(songs.flatMap(\.tags))

        let existing = (try? context.fetch(FetchDescriptor<BuiltInTag>())) ?? []
        let existingNames = Set(existing.map(\.name))

        for tag in existing where !incomingNames.contains(tag.name) {
            context.delete(tag)
        }
        for name in incomingNames where !existingNames.contains(name) {
            context.insert(BuiltInTag(name: name))
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
                  searchableCacheString: songStub.songTextDiacriticsInsensitive(),
                  sheets: songStub.sheets,
                  builtInTags: songStub.tags)
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
        self.builtInTags = songStub.tags
        // Note: user tags live on `UserTag.songNumbers` in a separate store and are
        // never touched here, so user data survives re-seed.
    }
}
