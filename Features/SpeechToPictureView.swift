import SwiftUI

struct SpeechToPictureView: View {
    private struct PictureChoice: Identifiable {
        let index: Int
        let word: String
        var id: Int { index }
    }

    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Binding var isTyping: Bool
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var transcriber = SpokenChoiceTranscriber()
    @State private var transcript = ""
    @State private var isPreparingRecording = false
    @State private var isTranscribing = false
    @State private var feedback: String?
    @State private var recordingAttemptID = UUID()
    @State private var pictureSelections: [Int: VisualMessagePictureSelection] = [:]
    @State private var pictureChoice: PictureChoice?
    @FocusState private var transcriptFocused: Bool

    private var parts: [VisualMessagePart] {
        store.visualMessageParts(for: transcript, pictureSelections: pictureSelections)
    }

    private func pictureDescription(for part: VisualMessagePart,
                                    labelsByID: [UUID: String]) -> String {
        guard let id = part.itemID, let label = labelsByID[id] else {
            return part.arasaacPictogramID == nil ? "Text only" : "ARASAAC pictogram"
        }
        return "Picture from \(label)"
    }

    var body: some View {
        let previewParts = parts
        let previewIDs = Set(previewParts.compactMap(\.itemID))
        let labelsByID = store.items.reduce(into: [UUID: String]()) { labels, item in
            if previewIDs.contains(item.id) && labels[item.id] == nil {
                labels[item.id] = store.displayLabel(for: item)
            }
        }
        return NavigationStack {
            Form {
                Section("Speak or type") {
                    Text("Say a message, then check the words. Recognition stays on this device, and the recording is deleted after transcription. You can also type the words.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(recorder.isRecording ? "Stop and review" : "Record a message",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording { stopAndTranscribe() }
                        else { startRecording() }
                    }
                    .disabled(isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("visual-message-record")
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    if isPreparingRecording || isTranscribing {
                        ProgressView(isTranscribing ? "Reading speech" : "Preparing microphone")
                    }
                    TextField("Review spoken words", text: $transcript, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($transcriptFocused)
                        .accessibilityIdentifier("visual-message-transcript")
                    if let feedback = feedback ?? recorder.errorMessage {
                        Text(feedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Picture preview") {
                    if previewParts.isEmpty {
                        Text("Your words will appear here as picture and text cards.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Matching words use your existing picture buttons. Other words stay as text. Choose a card to change its picture or find an ARASAAC pictogram.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                            ForEach(Array(previewParts.enumerated()), id: \.offset) { index, part in
                                Button {
                                    transcriptFocused = false
                                    pictureChoice = PictureChoice(index: index, word: part.text)
                                } label: {
                                VStack(spacing: 5) {
                                    if let imageData = part.imageData {
                                        AsyncThumbnailImage(data: imageData, maxPixelSize: 120,
                                                            contentMode: .fit) {
                                            Image(systemName: "textformat").font(.title)
                                        }
                                            .frame(height: 58)
                                            .accessibilityHidden(true)
                                    } else if let symbol = part.symbol, !symbol.isEmpty {
                                        Text(symbol)
                                            .font(.system(size: 44))
                                            .frame(height: 58)
                                            .accessibilityHidden(true)
                                    } else {
                                        Image(systemName: "textformat")
                                            .font(.title)
                                            .frame(height: 58)
                                            .accessibilityHidden(true)
                                    }
                                    Text(part.text)
                                        .font(.subheadline.weight(.medium))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                    Text("Change picture")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .padding(7)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Change picture for \(part.text)")
                                .accessibilityValue(pictureDescription(for: part, labelsByID: labelsByID))
                                .accessibilityIdentifier("visual-message-part-\(index)")
                            }
                        }
                        .accessibilityIdentifier("visual-message-preview")
                    }
                }

                Section {
                    Button("Add to picture message", systemImage: "plus.circle.fill") {
                        addReviewedMessage()
                    }
                    .disabled(previewParts.isEmpty || recorder.isRecording || isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("visual-message-add")
                }
            }
            .navigationTitle("Speech to pictures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(previewParts.count == 1 ? "Choose picture" : "Choose first picture") {
                        guard let first = previewParts.first else { return }
                        transcriptFocused = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(200))
                            pictureChoice = PictureChoice(index: 0, word: first.text)
                        }
                    }
                    .disabled(previewParts.isEmpty)
                    .accessibilityIdentifier("visual-message-choose-first-picture")
                }
            }
            .sheet(item: $pictureChoice) { choice in
                VisualMessagePicturePicker(word: choice.word) { selection in
                    if let selection { pictureSelections[choice.index] = selection }
                    else { pictureSelections.removeValue(forKey: choice.index) }
                    pictureChoice = nil
                }
            }
            .onChange(of: transcript) { _, _ in
                pictureSelections.removeAll()
                pictureChoice = nil
            }
            .onChange(of: store.activeProfileID) { _, _ in
                pictureSelections.removeAll()
                pictureChoice = nil
            }
            .onDisappear { discardPendingSpeech() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { discardPendingSpeech() }
            }
        }
    }

    private func addReviewedMessage() {
        guard !recorder.isRecording && !isPreparingRecording && !isTranscribing,
              store.appendVisualMessage(transcript, pictureSelections: pictureSelections) else { return }
        isTyping = false
        dismiss()
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
            feedback = "The recording could not be read. Try again or type the words."
            return
        }
        let attemptID = recordingAttemptID
        isTranscribing = true
        feedback = nil
        Task {
            defer { isTranscribing = false }
            do {
                let words = try await transcriber.transcribe(data)
                guard recordingAttemptID == attemptID else { return }
                transcript = words
                feedback = "Review the words and pictures before adding them."
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
