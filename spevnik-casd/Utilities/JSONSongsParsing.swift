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
    var sheets: [String]

    init(number: Int, title: String, verses: [VerseStub], sheets: [String] = []) {
        self.number = number
        self.title = title
        self.verses = verses
        self.sheets = sheets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.number = try container.decode(Int.self, forKey: .number)
        self.title = try container.decode(String.self, forKey: .title)
        self.verses = try container.decode([VerseStub].self, forKey: .verses)
        // `sheets` was added later; tolerate archives that predate it.
        self.sheets = try container.decodeIfPresent([String].self, forKey: .sheets) ?? []
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
