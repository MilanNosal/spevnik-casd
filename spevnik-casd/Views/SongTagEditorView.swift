import SwiftUI
import SwiftData

/// Per-song tag editor. Lets the user toggle and create user tags for a song.
/// Built-in tags are shown read-only.
struct SongTagEditorView: View {

    let song: Song

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \UserTag.name) private var allUserTags: [UserTag]

    @State private var newTagName = ""
    @State private var tagPendingDeletion: UserTag?

    var body: some View {
        NavigationStack {
            List {
                Section("Moje témy") {
                    ForEach(allUserTags) { tag in
                        row(for: tag)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    tagPendingDeletion = tag
                                } label: {
                                    Label("Odstrániť", systemImage: "trash")
                                }
                            }
                    }
                    addTagField
                }

                if !song.builtInTags.isEmpty {
                    Section("Témy zo spevníka") {
                        ForEach(song.builtInTags.sorted(), id: \.self) { name in
                            row(for: name)
                        }
                    }
                }
            }
            .navigationTitle(song.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hotovo") { dismiss() }
                }
            }
            .confirmationDialog(
                tagPendingDeletion.map { "Odstrániť tému „\($0.name)“?" } ?? "",
                isPresented: Binding(
                    get: { tagPendingDeletion != nil },
                    set: { if !$0 { tagPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: tagPendingDeletion
            ) { tag in
                Button("Odstrániť zo všetkých piesní", role: .destructive) {
                    delete(tag)
                }
                Button("Zrušiť", role: .cancel) { }
            } message: { _ in
                Text("Téma sa odstráni zo všetkých piesní, ku ktorým je priradená.")
            }
        }
    }
    
    @ViewBuilder
    private func row(for tag: UserTag) -> some View {
        let isAssigned = song.userTags.contains { $0.name == tag.name }
        Button {
            toggle(tag)
        } label: {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.primary)
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isAssigned {
                    Image(systemName: "checkmark").foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func row(for builtInTag: String) -> some View {
        HStack {
            Image(systemName: "tag.fill")
                .foregroundStyle(.secondary)
            Text(builtInTag)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private var addTagField: some View {
        HStack {
            TextField("Nová téma", text: $newTagName)
                .textInputAutocapitalization(.sentences)
                .onSubmit(addTag)
            Button(action: addTag) {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(trimmedNewTagName.isEmpty)
        }
    }

    private var trimmedNewTagName: String {
        newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deletes a user tag globally. The `.nullify` inverse on `Song.userTags`
    /// removes it from every song automatically.
    private func delete(_ tag: UserTag) {
        modelContext.delete(tag)
        tagPendingDeletion = nil
    }

    private func toggle(_ tag: UserTag) {
        if let index = song.userTags.firstIndex(where: { $0.name == tag.name }) {
            song.userTags.remove(at: index)
        } else {
            song.userTags.append(tag)
        }
    }

    private func addTag() {
        let name = trimmedNewTagName
        guard !name.isEmpty else { return }

        // Reuse an existing tag of the same name, otherwise create one.
        let tag: UserTag
        if let existing = allUserTags.first(where: { $0.name == name }) {
            tag = existing
        } else {
            tag = UserTag(name: name)
            modelContext.insert(tag)
        }
        if !song.userTags.contains(where: { $0.name == name }) {
            song.userTags.append(tag)
        }
        newTagName = ""
    }
}
