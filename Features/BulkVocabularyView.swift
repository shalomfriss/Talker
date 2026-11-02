import SwiftUI

struct BulkVocabularyView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var board: String
    @State private var createNewBoard = false
    @State private var newBoardName = ""
    @State private var input = ""
    @State private var usesColor = false
    @State private var color = Color(red: 0.86, green: 0.95, blue: 0.89)
    @State private var addedCount: Int?
    @State private var savedBoard = ""
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var transcriber = SpokenChoiceTranscriber()
    @State private var isPreparingRecording = false
    @State private var isTranscribing = false
    @State private var recordingAttemptID = UUID()
    @State private var feedback: String?

    init(initialBoard: String, startsWithNewBoard: Bool = false) {
        _board = State(initialValue: initialBoard)
        _createNewBoard = State(initialValue: startsWithNewBoard)
    }

    var body: some View {
        let destination = createNewBoard ? newBoardName.trimmingCharacters(in: .whitespacesAndNewlines) : board
        let preview = BulkVocabulary.preview(input, board: destination, existing: store.items)
        let validDestination = createNewBoard
            ? !destination.isEmpty && destination.localizedCaseInsensitiveCompare("Favorites") != .orderedSame
                && !store.categories.contains(where: { $0.localizedCaseInsensitiveCompare(destination) == .orderedSame })
            : store.categories.contains(board)
        return NavigationStack {
            Form {
                Section("Destination board") {
                    Picker("Save to", selection: $createNewBoard) {
                        Text("Existing board").tag(false)
                        Text("New board").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("bulk-destination-type")
                    if createNewBoard {
                        TextField("New board name", text: $newBoardName)
                            .accessibilityIdentifier("bulk-new-board-name")
                        if !destination.isEmpty && !validDestination {
                            Text("Use a unique board name other than Favorites.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Picker("Board", selection: $board) {
                            ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                        }
                        .accessibilityIdentifier("bulk-board")
                    }
                }
                Section("Create with your voice") {
                    Text("Say each button name, with ‘next button’ between names. Check and edit the list below before saving. Recognition stays on this device; the recording is deleted after transcription.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(recorder.isRecording ? "Stop and review" : "Record button names",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording { stopAndTranscribe() }
                        else { startRecording() }
                    }
                    .disabled(isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("bulk-record-buttons")
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    if isPreparingRecording || isTranscribing {
                        ProgressView(isTranscribing ? "Reading speech" : "Preparing microphone")
                    }
                    if let message = feedback ?? recorder.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Words or phrases") {
                    TextEditor(text: $input)
                        .frame(minHeight: 150)
                        .accessibilityIdentifier("bulk-words-input")
                    Text("Review spoken names here, or type or paste names separated by commas or new lines. For a personal symbol or spoken message, put one entry on a line as: label | emoji | spoken message")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Button color") {
                    Toggle("Give new buttons one color", isOn: $usesColor)
                        .accessibilityIdentifier("bulk-use-color")
                    if usesColor {
                        ColorPicker("Color", selection: $color, supportsOpacity: false)
                            .accessibilityIdentifier("bulk-color")
                    }
                }
                Section("Preview") {
                    if preview.inputTooLong {
                        Text("The pasted list is too long. Use fewer than \(BulkVocabulary.maximumInputCharacters) characters.")
                            .foregroundStyle(.red)
                    } else if preview.exceedsLimit {
                        Text("This list has more than \(BulkVocabulary.maximumEntries) new buttons. Split it into batches before adding.")
                            .foregroundStyle(.red)
                    } else if preview.entries.isEmpty {
                        Text("No new buttons to add yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(preview.entries.count) new \(preview.entries.count == 1 ? "button" : "buttons") for \(destination)")
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("bulk-preview-count")
                        ForEach(Array(preview.entries.prefix(20).enumerated()), id: \.offset) { indexed in
                            let entry = indexed.element
                            HStack(spacing: 12) {
                                Text(entry.symbol).font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading) {
                                    Text(entry.label)
                                    if entry.message != entry.label {
                                        Text("Says: \(entry.message)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if preview.entries.count > 20 {
                            Text("And \(preview.entries.count - 20) more buttons")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if preview.existingCount > 0 {
                        Text("\(preview.existingCount) already on this board will be skipped.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("bulk-existing-count")
                    }
                    if preview.repeatedCount > 0 {
                        Text("\(preview.repeatedCount) repeated in the list will be skipped.")
                            .foregroundStyle(.secondary)
                    }
                    if preview.invalidCount > 0 {
                        Text("\(preview.invalidCount) incomplete or overlong entries will be skipped.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(createNewBoard ? "Make a quick board" : "Add several buttons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(preview.entries.count)") {
                        let colorHex = usesColor ? ButtonColorAppearance.hex(from: color) : nil
                        let count = createNewBoard
                            ? store.addBulkBoard(destination, entries: preview.entries, backgroundColorHex: colorHex)
                            : store.addBulkItems(preview.entries, to: board, backgroundColorHex: colorHex)
                        if count > 0 {
                            savedBoard = destination
                            addedCount = count
                        } else {
                            feedback = "Could not add these buttons. Check the board name and try again."
                        }
                    }
                    .disabled(!preview.canAdd || !validDestination || recorder.isRecording
                              || isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("bulk-add-buttons")
                }
            }
            .alert("\(addedCount ?? 0) buttons added to \(savedBoard)", isPresented: Binding(
                get: { addedCount != nil }, set: { if !$0 { addedCount = nil } }
            )) {
                Button("Done") { dismiss() }
            }
            .onDisappear { discardPendingSpeech() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { discardPendingSpeech() }
            }
        }
    }

    private func startRecording() {
        let attemptID = UUID()
        recordingAttemptID = attemptID
        feedback = nil
        isPreparingRecording = true
        store.stopSpeaking()
        Task {
            defer { isPreparingRecording = false }
            do {
                try await transcriber.prepare(language: store.settings.communicationLanguage)
                guard recordingAttemptID == attemptID else { return }
                await recorder.start()
            } catch {
                guard recordingAttemptID == attemptID else { return }
                feedback = error.localizedDescription
            }
        }
    }

    private func stopAndTranscribe() {
        guard let data = recorder.stop() else {
            feedback = "The recording could not be read. Try again or type the names."
            return
        }
        let attemptID = recordingAttemptID
        isTranscribing = true
        feedback = nil
        Task {
            defer { isTranscribing = false }
            do {
                let names = BulkVocabulary.editableList(from: try await transcriber.transcribe(data))
                guard recordingAttemptID == attemptID else { return }
                if !names.isEmpty {
                    input += input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? names : "\n\(names)"
                    feedback = "Review the button names below before saving."
                } else {
                    feedback = "No button names were heard. Try again or type the names."
                }
            } catch is CancellationError {
                // Closing this screen cancels transcription.
            } catch {
                guard recordingAttemptID == attemptID else { return }
                feedback = error.localizedDescription
            }
        }
    }

    private func discardPendingSpeech() {
        recordingAttemptID = UUID()
        recorder.discard()
        transcriber.cancel()
        isPreparingRecording = false
        isTranscribing = false
    }
}
