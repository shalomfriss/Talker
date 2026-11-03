import SwiftUI

struct SingleButtonView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSetup = false
    @State private var recordingPhrase: SavedPhrase?

    var body: some View {
        NavigationStack {
            Group {
                if let phrase = store.singleButtonPhrase {
                    Button {
                        store.speakPhrase(phrase)
                    } label: {
                        VStack(spacing: 28) {
                            Image(systemName: phrase.audioData == nil ? "speaker.wave.3.fill" : "waveform")
                                .font(.system(size: 72, weight: .semibold))
                            Text(phrase.text)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.45)
                                .multilineTextAlignment(.center)
                                .lineLimit(6)
                        }
                        .foregroundStyle(store.settings.highContrast ? Color.white : Color.primary)
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(store.settings.highContrast ? Color.black : Color(red: 0.88, green: 0.93, blue: 1),
                                    in: RoundedRectangle(cornerRadius: 30))
                        .contentShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("single-button-play")
                    .accessibilityLabel("Speak \(phrase.text)")
                    .accessibilityHint(phrase.audioData == nil ? "Speak with the system voice" : "Play the recorded voice")
                    .padding(16)
                } else {
                    ContentUnavailableView {
                        Label("Choose one message", systemImage: "speaker.wave.2")
                    } description: {
                        Text("Choose or create a phrase to use as your large communication button.")
                    } actions: {
                        Button("Set up button") { showingSetup = true }
                            .accessibilityIdentifier("single-button-empty-setup")
                    }
                }
            }
            .navigationTitle("One button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                if !store.settings.singleButtonLocked, let phrase = store.singleButtonPhrase {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Record", systemImage: "mic.fill") { recordingPhrase = phrase }
                            .accessibilityIdentifier("single-button-record-direct")
                    }
                }
                if !store.settings.singleButtonLocked || store.singleButtonPhrase == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Set up", systemImage: "gearshape") { showingSetup = true }
                            .accessibilityIdentifier("single-button-setup")
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                NavigationStack {
                    SingleButtonSetupView()
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSetup = false }
                        } }
                }
            }
            .sheet(item: $recordingPhrase) { PhraseRecordingEditorView(phrase: $0) }
            .onChange(of: store.activeProfileID) { _, _ in recordingPhrase = nil }
        }
    }
}

struct SingleButtonSetupView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var newPhrase = ""
    @State private var addError = ""
    @State private var editingPhrase: SavedPhrase?
    @State private var recordingPhrase: SavedPhrase?

    private var selectablePhrases: [SavedPhrase] {
        store.phrases.filter { PhraseTemplate.fields(in: $0.text).isEmpty }
    }

    var body: some View {
        Form {
            Section {
                if let phrase = store.singleButtonPhrase {
                    Text(phrase.text)
                        .font(.headline)
                    Button("Edit message", systemImage: "pencil") { editingPhrase = phrase }
                        .accessibilityIdentifier("single-button-edit")
                    Button(phrase.audioData == nil ? "Record a voice" : "Change recording",
                           systemImage: "mic") { recordingPhrase = phrase }
                        .accessibilityIdentifier("single-button-record")
                } else {
                    Text("Choose a phrase below or create one.")
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Current message") }

            Section {
                Button {
                    store.settings.singleButtonLocked.toggle()
                } label: {
                    Label(store.settings.singleButtonLocked ? "Show editing in one button mode" : "Hide editing in one button mode",
                          systemImage: store.settings.singleButtonLocked ? "lock.fill" : "lock.open")
                }
                    .accessibilityIdentifier("single-button-lock")
                Text("You can always change the message here in Quick phrases. The large button stays available for speaking.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: { Text("Access") }

            Section("Create a message") {
                TextField("What should the button say?", text: $newPhrase, axis: .vertical)
                    .accessibilityIdentifier("single-button-new-message")
                if !addError.isEmpty { Text(addError).foregroundStyle(.red) }
                Button("Create and choose", systemImage: "plus") {
                    let text = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !PhraseTemplate.fields(in: text).isEmpty {
                        addError = "Use a complete message without blanks for this button."
                    } else if store.addPhrase(text), let phrase = store.phrases.first(where: { $0.text == text }) {
                        store.selectSingleButtonPhrase(phrase)
                        newPhrase = ""
                        addError = ""
                    } else {
                        addError = "Enter a new phrase that is not already saved."
                    }
                }
                .disabled(newPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("single-button-create")
            }

            Section("Choose a saved phrase") {
                ForEach(selectablePhrases) { phrase in
                    Button {
                        store.selectSingleButtonPhrase(phrase)
                    } label: {
                        HStack {
                            Text(phrase.text)
                                .foregroundStyle(.primary)
                            Spacer()
                            if store.singleButtonPhrase?.id == phrase.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("single-button-choice-\(phrase.id.uuidString)")
                }
            }
        }
        .navigationTitle("One button setup")
        .sheet(item: $editingPhrase) { PhraseTextEditorView(phrase: $0) }
        .sheet(item: $recordingPhrase) { PhraseRecordingEditorView(phrase: $0) }
        .onChange(of: store.activeProfileID) { _, _ in
            newPhrase = ""
            addError = ""
            editingPhrase = nil
            recordingPhrase = nil
        }
    }
}
