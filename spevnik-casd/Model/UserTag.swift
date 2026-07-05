import SwiftData

/// A user-defined tag. Stored separately from built-in tags (which live as plain
/// strings on `Song.builtInTags`) so that it survives the destructive song
/// re-seed — the seed loop never references this relationship.
@Model
final class UserTag {
    @Attribute(.unique)
    var name: String
    var songs: [Song] = []

    init(name: String) {
        self.name = name
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
