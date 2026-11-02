import SwiftUI

struct SpeechToPictureView: View {
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
    @State private var selectingPartIndex = 0
    @State private var selectingPartText = ""
    @State private var showingPictureChoices = false

    private var parts: [VisualMessagePart] {
        store.visualMessageParts(for: transcript, pictureSelections: pictureSelections)
    }

    private func pictureDescription(for part: VisualMessagePart) -> String {
        guard let id = part.itemID, let item = store.items.first(where: { $0.id == id }) else {
            return "Text only"
        }
        return "Picture from \(store.displayLabel(for: item))"
    }

    var body: some View {
        NavigationStack {
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
                        .accessibilityIdentifier("visual-message-transcript")
                    if let feedback = feedback ?? recorder.errorMessage {
                        Text(feedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Picture preview") {
                    if parts.isEmpty {
                        Text("Your words will appear here as picture and text cards.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Matching words use your existing picture buttons. Other words stay as text.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                                Button {
                                    selectingPartIndex = index
                                    selectingPartText = part.text
                                    showingPictureChoices = true
                                } label: {
                                VStack(spacing: 5) {
                                    if let imageData = part.imageData,
                                       let image = UIImage(data: imageData) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
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
                                .accessibilityValue(pictureDescription(for: part))
                                .accessibilityIdentifier("visual-message-part-\(index)")
                            }
                        }
                        .accessibilityIdentifier("visual-message-preview")
                    }
                }

                Section {
                    Button("Add to picture message", systemImage: "plus.circle.fill") {
                        if store.appendVisualMessage(transcript, pictureSelections: pictureSelections) {
                            isTyping = false
                            dismiss()
                        }
                    }
                    .disabled(parts.isEmpty || recorder.isRecording || isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("visual-message-add")
                }
            }
            .navigationTitle("Speech to pictures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingPictureChoices) {
                VisualMessagePicturePicker(word: selectingPartText) { selection in
                    if let selection { pictureSelections[selectingPartIndex] = selection }
                    else { pictureSelections.removeValue(forKey: selectingPartIndex) }
                }
            }
            .onChange(of: transcript) { _, _ in
                pictureSelections.removeAll()
                showingPictureChoices = false
            }
            .onChange(of: store.activeProfileID) { _, _ in
                pictureSelections.removeAll()
                showingPictureChoices = false
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
