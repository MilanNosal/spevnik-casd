import SwiftUI

/// Sheet for choosing which tags to filter the song list by. Built-in and user
/// tags are shown in separate sections and are independently selectable.
struct TagFilterView: View {

    let builtInTags: [String]
    let userTags: [String]
    @Binding var selectedTags: Set<TagID>

    @Environment(\.dismiss) private var dismiss

    private var isEmpty: Bool {
        builtInTags.isEmpty && userTags.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    ContentUnavailableView("Žiadne témy",
                                           systemImage: "tag",
                                           description: Text("Zatiaľ nie sú k dispozícii žiadne témy."))
                } else {
                    List {
                        if !userTags.isEmpty {
                            Section("Moje témy") {
                                ForEach(userTags, id: \.self) { name in
                                    row(TagID(kind: .user, name: name), icon: "tag")
                                }
                            }
                        }
                        if !builtInTags.isEmpty {
                            Section("Témy zo spevníka") {
                                ForEach(builtInTags, id: \.self) { name in
                                    row(TagID(kind: .builtIn, name: name), icon: "tag.fill")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !selectedTags.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Vymazať") { selectedTags.removeAll() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hotovo") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ tag: TagID, icon: String) -> some View {
        let isSelected = selectedTags.contains(tag)
        Button {
            if isSelected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tag.kind == .builtIn ? Color.secondary : Color.primary)
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
