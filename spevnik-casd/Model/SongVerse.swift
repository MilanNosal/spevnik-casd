import SwiftData

@Model
final class SongVerse: Hashable {
    var orderIndex: Int
    var number: String
    var lines: [String]
    
    init(orderIndex: Int, number: String, lines: [String]) {
        self.orderIndex = orderIndex
        self.number = number
        self.lines = lines
    }
}
