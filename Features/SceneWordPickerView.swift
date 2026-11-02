import SwiftUI

struct SceneWordPickerView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (CommunicationItem) -> Void
    @State private var search = ""

    private var words: [CommunicationItem] {
        store.items.filter { item in
            item.destinationBoard == nil && (search.isEmpty ||
                item.label.localizedCaseInsensitiveContains(search) ||
                item.category.localizedCaseInsensitiveContains(search) ||
                store.displayLabel(for: item).localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List(words) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack {
                        Text(item.symbol).accessibilityHidden(true)
                        Text(store.displayLabel(for: item))
                        Spacer()
                        Text(item.category).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $search, prompt: "Find a word")
            .navigationTitle("Add a word")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
