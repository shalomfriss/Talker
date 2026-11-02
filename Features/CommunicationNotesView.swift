import SwiftUI

struct CommunicationNotesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onUseInDraft: () -> Void
    @State private var searchText = ""
    @State private var selectedTopic: String?
    @State private var showingNewNote = false
    @State private var editingNote: CommunicationNote?
    @State private var deletingNote: CommunicationNote?

    private var topics: [String] {
        Array(Set(store.notes.map(\.topic)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var visibleNotes: [CommunicationNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.notes.filter { note in
            (selectedTopic == nil || note.topic == selectedTopic) &&
            (query.isEmpty || note.title.localizedStandardContains(query) ||
             note.topic.localizedStandardContains(query) || note.text.localizedStandardContains(query))
        }
    }

    private var visibleTopics: [String] {
        topics.filter { topic in visibleNotes.contains(where: { $0.topic == topic }) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Keep information for a conversation. Notes stay with this profile and are included in its backups. They are not spoken or added to recent messages unless you choose to speak them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if visibleNotes.isEmpty {
                    ContentUnavailableView(searchText.isEmpty && store.notes.isEmpty ? "No notes yet" : "No matching notes",
                                           systemImage: "note.text",
                                           description: Text(store.notes.isEmpty ? "Add a note to prepare something you want to say." : "Try another search or topic."))
                } else {
                    ForEach(visibleTopics, id: \.self) { topic in
                        Section(topic) {
                            ForEach(visibleNotes.filter { $0.topic == topic }) { note in
                                noteRow(note)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .onChange(of: topics) { _, available in
                if let selectedTopic, !available.contains(selectedTopic) { self.selectedTopic = nil }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All topics") { selectedTopic = nil }
                        ForEach(topics, id: \.self) { topic in
                            Button(topic) { selectedTopic = topic }
                        }
                    } label: {
                        Label(selectedTopic ?? "All topics", systemImage: "line.3.horizontal.decrease")
                    }
                    .disabled(topics.isEmpty)
                    .accessibilityIdentifier("notes-topic-filter")
                }
                if !store.isBoardOnlyModeActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New note", systemImage: "plus") { showingNewNote = true }
                            .accessibilityIdentifier("new-note")
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) { CommunicationNoteEditorView(note: nil) }
            .sheet(item: $editingNote) { CommunicationNoteEditorView(note: $0) }
            .confirmationDialog("Delete note?", isPresented: Binding(
                get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } }
            )) {
                Button("Delete note", role: .destructive) {
                    if let deletingNote { _ = store.deleteNote(id: deletingNote.id) }
                    deletingNote = nil
                }
                Button("Cancel", role: .cancel) { deletingNote = nil }
            } message: {
                Text("This note will be removed from the current profile.")
            }
        }
    }

    private func noteRow(_ note: CommunicationNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title)
                .font(.headline)
            Text(note.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button("Speak", systemImage: "speaker.wave.2.fill") {
                    store.speakStandaloneMessage(note.text)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("speak-note-\(note.id)")
                Button("Use in text", systemImage: "text.badge.plus") {
                    guard store.appendTypedPhrase(note.text) else { return }
                    onUseInDraft()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Add this note to the current typed message")
                .accessibilityIdentifier("use-note-\(note.id)")
                Spacer(minLength: 0)
                Menu {
                    ShareLink(item: note.text) { Label("Share note", systemImage: "square.and.arrow.up") }
                    if !store.isBoardOnlyModeActive {
                        Button("Edit note", systemImage: "pencil") { editingNote = note }
                        Button("Delete note", systemImage: "trash", role: .destructive) { deletingNote = note }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Manage note \(note.title)")
                .accessibilityIdentifier("manage-note-\(note.id)")
            }
        }
        .padding(.vertical, 4)
    }
}
