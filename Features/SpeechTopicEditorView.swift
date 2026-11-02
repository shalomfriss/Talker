import SwiftUI

struct SpeechTopicEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var newTopic = ""
    @State private var editingTopic: SpeechTopic?
    @State private var editedText = ""
    @State private var errorText = ""

    var body: some View {
        List {
            Section("Add a topic") {
                TextField("Topic name", text: $newTopic)
                    .textInputAutocapitalization(.sentences)
                Button("Add topic", systemImage: "plus") {
                    if store.addSpeechTopic(newTopic) {
                        newTopic = ""
                        errorText = ""
                    } else {
                        errorText = "Choose a different topic name."
                    }
                }
                .disabled(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !errorText.isEmpty {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            Section("Your topics") {
                ForEach(store.speechTopics) { topic in
                    HStack {
                        Text(topic.text)
                        Spacer()
                        Button("Rename \(topic.text)", systemImage: "pencil") {
                            editedText = topic.text
                            editingTopic = topic
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Rename \(topic.text)")
                    }
                }
                .onMove(perform: store.moveSpeechTopics)
                .onDelete { indexes in
                    let ids = indexes.compactMap { store.speechTopics.indices.contains($0) ? store.speechTopics[$0].id : nil }
                    ids.forEach { store.deleteSpeechTopic(id: $0) }
                }
            }
        }
        .navigationTitle("Manage topics")
        .toolbar { EditButton() }
        .sheet(item: $editingTopic) { topic in
            NavigationStack {
                Form {
                    TextField("Topic name", text: $editedText)
                        .textInputAutocapitalization(.sentences)
                    if !errorText.isEmpty {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                .navigationTitle("Rename topic")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingTopic = nil; errorText = "" }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if store.renameSpeechTopic(id: topic.id, to: editedText) {
                                editingTopic = nil
                                errorText = ""
                            } else {
                                errorText = "Choose a different topic name."
                            }
                        }
                        .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onChange(of: store.activeProfileID) { _, _ in
            newTopic = ""
            editingTopic = nil
            errorText = ""
        }
    }
}
