import SwiftUI

struct WordKeyboardEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingKey: WordKeyboardKey?
    @State private var addingKey = false

    private var language: String { store.settings.communicationLanguage }
    private var keys: [WordKeyboardKey] { store.settings.wordsForKeyboard(language: language) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Columns", selection: $store.settings.wordKeyboardColumns) {
                        Text("Automatic").tag(0)
                        ForEach(2...4, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    Text("Drag keys to change their order. Tap a key to edit its text and spacing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Keys") {
                    ForEach(keys) { key in
                        Button {
                            editingKey = key
                        } label: {
                            HStack {
                                Text(key.label)
                                    .font(.headline)
                                Spacer()
                                Text(key.text)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("edit-word-key-\(key.id)")
                    }
                    .onMove { source, destination in
                        var updated = keys
                        updated.move(fromOffsets: source, toOffset: destination)
                        store.settings.setWordsForKeyboard(updated, language: language)
                    }
                    .onDelete { offsets in
                        var updated = keys
                        updated.remove(atOffsets: offsets)
                        store.settings.setWordsForKeyboard(updated, language: language)
                    }
                }
            }
            .navigationTitle("Edit word keys")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add key", systemImage: "plus") { addingKey = true }
                        .disabled(keys.count >= 40)
                        .accessibilityIdentifier("add-word-key")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editingKey) { key in
                WordKeyboardKeyForm(key: key) { saved in
                    var updated = keys
                    guard let index = updated.firstIndex(where: { $0.id == key.id }) else { return }
                    updated[index] = saved
                    store.settings.setWordsForKeyboard(updated, language: language)
                }
            }
            .sheet(isPresented: $addingKey) {
                WordKeyboardKeyForm(key: WordKeyboardKey(label: "", text: "")) { saved in
                    store.settings.setWordsForKeyboard(keys + [saved], language: language)
                }
            }
        }
    }
}

private struct WordKeyboardKeyForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WordKeyboardKey
    let onSave: (WordKeyboardKey) -> Void

    init(key: WordKeyboardKey, onSave: @escaping (WordKeyboardKey) -> Void) {
        _draft = State(initialValue: key)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Key label", text: $draft.label)
                    .accessibilityIdentifier("word-key-label")
                TextField("Text to insert", text: $draft.text)
                    .accessibilityIdentifier("word-key-text")
                Section("Spacing") {
                    Toggle("Add space before", isOn: $draft.spaceBefore)
                    Toggle("Add space after", isOn: $draft.spaceAfter)
                }
                Text("Turn off space before for punctuation. Turn off space after to join the next key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Word key")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        draft.label = String(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        draft.text = String(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-word-key")
                }
            }
        }
    }
}
