import SwiftData

@Model
final class Song: Hashable {
    @Attribute(.unique)
    var number: Int
    var title: String
    var verses: [SongVerse]
    var searchableCacheString: String

    init(number: Int, title: String, verses: [SongVerse], searchableCacheString: String) {
        self.number = number
        self.title = title
        self.verses = verses
        self.searchableCacheString = searchableCacheString
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }
}
