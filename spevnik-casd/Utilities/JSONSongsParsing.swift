import Foundation

func parseSongsFromArchive() -> [SongStub]? {
    guard let url = Bundle.main.url(forResource: "spevnik", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let songs = try? JSONDecoder().decode([SongStub].self, from: data) else {
        return nil
    }
    return songs
}

struct SongStub: Codable {
    var number: Int
    var title: String
    var verses: [VerseStub]
    
    init(number: Int, title: String, verses: [VerseStub]) {
        self.number = number
        self.title = title
        self.verses = verses
    }
    
    func songTextDiacriticsInsensitive() -> String {
        let songText = verses.map({ $0.lines.joined(separator: " ") }).joined(separator: "\n")
        let fullSong = "\(number) \(title)\n\(songText)"
        return fullSong.folding(options: .diacriticInsensitive, locale: Locale.current).uppercased()
    }
}

struct VerseStub: Codable {
    var number: String
    var lines: [String]
    
    init(number: String, lines: [String]) {
        self.number = number
        self.lines = lines
    }
}
