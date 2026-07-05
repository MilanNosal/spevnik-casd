import SwiftData

@Model
final class Song: Hashable {
    @Attribute(.unique)
    var number: Int
    var title: String
    var verses: [SongVerse]
    var searchableCacheString: String
    var sheets: [String] = []

    /// Built-in tags, re-seeded from the bundled JSON. Safe to overwrite on update.
    var builtInTags: [String] = []

    init(number: Int, title: String, verses: [SongVerse], searchableCacheString: String, sheets: [String] = [], builtInTags: [String] = []) {
        self.number = number
        self.title = title
        self.verses = verses
        self.searchableCacheString = searchableCacheString
        self.sheets = sheets
        self.builtInTags = builtInTags
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }

    /// Whether this song carries the given built-in tag. User-tag membership lives
    /// on `UserTag.songNumbers` and is resolved by the caller.
    func matchesBuiltIn(_ name: String) -> Bool {
        builtInTags.contains(name)
    }
}
