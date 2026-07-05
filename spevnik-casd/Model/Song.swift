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

    /// User-defined tags. Never touched by the seed loop, so they survive re-seed.
    @Relationship(deleteRule: .nullify, inverse: \UserTag.songs)
    var userTags: [UserTag] = []

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

    /// Whether this song carries the given tag, checking the correct namespace.
    func matches(_ tag: TagID) -> Bool {
        switch tag.kind {
        case .builtIn: return builtInTags.contains(tag.name)
        case .user:    return userTags.contains { $0.name == tag.name }
        }
    }
}
