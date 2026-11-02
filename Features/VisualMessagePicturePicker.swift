import SwiftUI

struct VisualMessagePicturePicker: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    let word: String
    let onSelect: (VisualMessagePictureSelection?) -> Void

    private var availableItems: [CommunicationItem] {
        store.items.filter { item in
            item.effectiveAction == .addToMessage && item.boardVisibility != .hidden
                && (item.imageData != nil || !item.symbol.isEmpty)
                && (search.isEmpty || store.displayLabel(for: item).localizedStandardContains(search)
                    || item.category.localizedStandardContains(search))
        }.sorted {
            store.displayLabel(for: $0).localizedStandardCompare(store.displayLabel(for: $1)) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("For \(word)") {
                    Button("Use automatic picture", systemImage: "sparkles") { choose(nil) }
                        .accessibilityIdentifier("visual-picture-automatic")
                    Button("Text only", systemImage: "textformat") { choose(.textOnly) }
                        .accessibilityIdentifier("visual-picture-text-only")
                }
                Section("My picture buttons") {
                    if availableItems.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        ForEach(availableItems) { item in
                            Button {
                                choose(.item(item.id))
                            } label: {
                                HStack(spacing: 12) {
                                    if let data = item.imageData, let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 48, height: 48)
                                            .accessibilityHidden(true)
                                    } else {
                                        Text(item.symbol)
                                            .font(.title)
                                            .frame(width: 48, height: 48)
                                            .accessibilityHidden(true)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.displayLabel(for: item))
                                            .foregroundStyle(.primary)
                                        Text(item.category)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .accessibilityLabel("Use \(store.displayLabel(for: item)) picture")
                            .accessibilityIdentifier("visual-picture-option-\(item.id.uuidString)")
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Find a picture button")
            .navigationTitle("Choose picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func choose(_ selection: VisualMessagePictureSelection?) {
        onSelect(selection)
        dismiss()
    }
}
