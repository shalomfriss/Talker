import SwiftUI

struct CommunicationNoteEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let note: CommunicationNote?
    @State private var title: String
    @State private var topic: String
    @State private var text: String

    init(note: CommunicationNote?) {
        self.note = note
        _title = State(initialValue: note?.title ?? "")
        _topic = State(initialValue: note?.topic ?? "")
        _text = State(initialValue: note?.text ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Find it later") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("note-title")
                    TextField("Topic (optional)", text: $topic)
                        .accessibilityIdentifier("note-topic")
                }
                Section("What you want to remember or say") {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Note text")
                        .accessibilityIdentifier("note-text")
                }
            }
            .navigationTitle(note == nil ? "New note" : "Edit note")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if store.saveNote(id: note?.id, title: title, topic: topic, text: text) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-note")
                }
            }
        }
    }
}
