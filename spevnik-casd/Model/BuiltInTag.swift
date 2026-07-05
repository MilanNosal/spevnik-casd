import SwiftData

/// Deduplicated catalog of built-in tag names, reconciled from the bundled JSON
/// during the song re-seed. Lets the filter UI list all built-in tags without
/// flat-mapping every song on each render. Per-song membership still lives in
/// `Song.builtInTags`.
@Model
final class BuiltInTag {
    @Attribute(.unique)
    var name: String

    init(name: String) {
        self.name = name
    }
}
