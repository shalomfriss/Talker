import SwiftUI

struct CommunicationPassportView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CommunicationPassport()
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            Form {
                if isEditing {
                    editor
                } else if store.passport.isEmpty {
                    Section {
                        Text("Describe how you communicate and what you want others to know. Share only when you choose.")
                            .foregroundStyle(.secondary)
                        Button("Create my passport", systemImage: "square.and.pencil") { startEditing() }
                    }
                } else {
                    Section {
                        Button("Speak my passport", systemImage: "speaker.wave.2.fill") {
                            store.speak(store.passport.shareText)
                        }
                        ShareLink(item: store.passport.shareText) {
                            Label("Share my passport", systemImage: "square.and.arrow.up")
                        }
                    }
                    ForEach(store.passport.entries.indices, id: \.self) { index in
                        let entry = store.passport.entries[index]
                        Section(entry.title) {
                            Text(entry.value)
                                .font(.title3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle("My communication passport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Cancel") { isEditing = false }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            store.updatePassport(draft)
                            isEditing = false
                        }
                    } else if !store.passport.isEmpty {
                        Button("Edit") { startEditing() }
                    }
                }
            }
            .onChange(of: store.activeProfileID) { _, _ in
                draft = store.passport
                isEditing = false
            }
        }
    }

    private var editor: some View {
        Group {
            Section("My name") {
                TextField("Name I want to use", text: $draft.name)
                    .accessibilityIdentifier("passport-name")
                    .accessibilityLabel("My name")
            }
            Section("About me") {
                TextField("What I want people to know", text: $draft.introduction, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("About me")
            }
            Section("How I communicate") {
                TextField("Words, AAC, gestures, or other ways", text: $draft.communicationMethods, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("How I communicate")
            }
            Section("What helps me communicate") {
                TextField("What others can do to help", text: $draft.helpfulSupport, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("What helps me communicate")
            }
            Section("Please respect") {
                TextField("My choices and boundaries", text: $draft.boundaries, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("Please respect")
            }
            Section("When I feel overwhelmed") {
                TextField("What I want others to do", text: $draft.whenOverwhelmed, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("When I feel overwhelmed")
            }
            Section("Things I like to talk about") {
                TextField("My interests", text: $draft.interests, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("Things I like to talk about")
            }
        }
    }

    private func startEditing() {
        draft = store.passport
        isEditing = true
    }
}
