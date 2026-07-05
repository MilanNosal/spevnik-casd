import SwiftData

/// A user-defined tag. Self-contained: it references songs by their stable
/// `number` rather than a SwiftData relationship, so it is fully decoupled from
/// the destructively re-seeded `Song` store and survives re-seeds.
///
/// Being self-contained (name + song numbers, trivially Codable) also makes it
/// ready to mirror to iCloud via `NSUbiquitousKeyValueStore` later. That path
/// keeps the SwiftData store local-only, so the unique-name constraint is fine.
@Model
final class UserTag {
    @Attribute(.unique)
    var name: String
    var songNumbers: [Int] = []

    init(name: String, songNumbers: [Int] = []) {
        self.name = name
        self.songNumbers = songNumbers
    }

    func contains(songNumber: Int) -> Bool {
        songNumbers.contains(songNumber)
    }
}

/// Distinguishes the two tag namespaces. A built-in "Advent" and a user "Advent"
/// are different tags.
enum TagKind: Hashable {
    case builtIn
    case user
}

/// Stable identity for a tag across both namespaces, used for filter selection
/// and list rows. Names can collide between kinds, so identity is kind + name.
struct TagID: Hashable, Identifiable {
    let kind: TagKind
    let name: String

    var id: String { "\(kind)::\(name)" }
}
