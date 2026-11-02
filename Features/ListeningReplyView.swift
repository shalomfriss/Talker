import SwiftUI

struct ListeningReplyView: View {
    private enum FocusedField: Hashable {
        case transcript
        case reply
    }

    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var transcriber = SpokenChoiceTranscriber()
    @State private var transcript = ""
    @State private var draftReply = ""
    @State private var selectedReply: ListeningReply?
    @State private var isPreparingRecording = false
    @State private var isTranscribing = false
    @State private var feedback: String?
    @State private var recordingAttemptID = UUID()
    @FocusState private var focusedField: FocusedField?

    private var suggestions: [ListeningReply] {
        ListeningReplies.suggestions(for: transcript,
                                     language: store.settings.communicationLanguage,
                                     phrases: store.phrases,
                                     quickReplies: store.settings.quickResponses)
    }

    private var hasTranscript: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var replyComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your reply").font(.headline)
            TextField("Type or edit your reply", text: $draftReply, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .reply)
                .accessibilityIdentifier("listen-draft")
            Button("Speak reply", systemImage: "speaker.wave.2.fill") {
                let recording = selectedReply?.text == draftReply ? selectedReply?.audioData : nil
                store.speakStandaloneMessage(draftReply, audioData: recording)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draftReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || recorder.isRecording || isPreparingRecording || isTranscribing)
            .accessibilityIdentifier("listen-speak")
        }
        .frame(maxWidth: 720, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Let the other person know when the microphone is on. Speech is recognized on this device; the recording is deleted after transcription. Only a reply you choose to speak can enter your optional spoken history.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("What did they say?").font(.headline)
                        Button(recorder.isRecording ? "Stop and review" : "Listen to a question",
                               systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                            if recorder.isRecording { stopAndTranscribe() }
                            else { startRecording() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPreparingRecording || isTranscribing)
                        .accessibilityIdentifier("listen-record")
                        if recorder.isRecording {
                            Label("Recording", systemImage: "waveform")
                                .foregroundStyle(.red)
                            Button("Cancel recording") { discardPendingSpeech() }
                                .accessibilityIdentifier("listen-cancel")
                        }
                        if isPreparingRecording || isTranscribing {
                            ProgressView(isTranscribing ? "Reading speech" : "Preparing microphone")
                        }
                        TextField("Review or type their words", text: $transcript, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .transcript)
                            .accessibilityIdentifier("listen-transcript")
                        if let feedback = feedback ?? recorder.errorMessage {
                            Text(feedback)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if hasTranscript {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Choose a reply").font(.headline)
                            Text("Suggestions are starting points. Select one to review or change it before speaking.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                                ForEach(suggestions) { reply in
                                    Button {
                                        selectedReply = reply
                                        draftReply = reply.text
                                        focusedField = nil
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(reply.text)
                                                .font(.body.weight(.medium))
                                                .multilineTextAlignment(.leading)
                                            if reply.source == .personalPhrase {
                                                Text("My phrase")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                                        .padding(10)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(selectedReply?.id == reply.id ? .indigo : .primary)
                                    .accessibilityIdentifier("listen-reply-\(reply.id)")
                                }
                            }
                        }
                    }

                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding()
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { replyComposer }
            .navigationTitle("Listen and reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: transcript) { _, _ in
                selectedReply = nil
            }
            .onChange(of: store.activeProfileID) { _, _ in
                discardPendingSpeech()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { discardPendingSpeech() }
            }
            .onDisappear { discardPendingSpeech() }
        }
    }

    private func startRecording() {
        let attemptID = UUID()
        recordingAttemptID = attemptID
        feedback = nil
        isPreparingRecording = true
        store.stopSpeaking()
        Task {
            defer { if recordingAttemptID == attemptID { isPreparingRecording = false } }
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
            defer { if recordingAttemptID == attemptID { isTranscribing = false } }
            do {
                let words = try await transcriber.transcribe(data)
                guard recordingAttemptID == attemptID else { return }
                transcript = words
                feedback = "Check their words, then choose or type your own reply."
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
        transcript = ""
        draftReply = ""
        selectedReply = nil
        focusedField = nil
    }
}
