import SwiftUI

struct WordManagerView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var editingItem: CommunicationItem?
    @FocusState private var searchFocused: Bool

    private var matchingItems: [CommunicationItem] {
        let items = search.isEmpty ? store.items : store.items.filter {
            $0.label.localizedCaseInsensitiveContains(search)
                || store.translation(for: $0)?.label.localizedCaseInsensitiveContains(search) == true
        }
        return items.sorted {
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Find a word", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($searchFocused)
                        .onSubmit { searchFocused = false }
                        .accessibilityIdentifier("word-manager-search")
                    if !search.isEmpty {
                        Button("Clear search", systemImage: "xmark.circle.fill") { search = "" }
                            .labelStyle(.iconOnly)
                    }
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                List(matchingItems) { item in
                    HStack(spacing: 12) {
                        Text(item.symbol).font(.title2).accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(item.label).font(.headline)
                            Text(item.category).font(.caption).foregroundStyle(.secondary)
                            if item.effectiveAction != .addToMessage {
                                Text(item.effectiveAction.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            if item.boardVisibility != .shown {
                                Text(item.boardVisibility.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("visibility-\(item.label)")
                            }
                            if let translation = store.translation(for: item) {
                                Text("Español: \(translation.label)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(item.isFavorite ? "Remove favorite" : "Add favorite",
                               systemImage: item.isFavorite ? "star.fill" : "star") {
                            store.toggleFavorite(item)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityLabel(item.isFavorite ? "Remove \(item.label) from favorites" : "Add \(item.label) to favorites")
                        Button("Edit \(item.label)", systemImage: "pencil") {
                            searchFocused = false
                            editingItem = item
                        }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Edit \(item.label)")
                    }
                }
            }
            .navigationTitle("Edit words")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(item: $editingItem) { ItemEditorView(item: $0, category: $0.category) }
        }
    }
}
