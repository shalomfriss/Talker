import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct PhraseRecordingEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var audioData: Data?
    @State private var showingImporter = false
    @State private var importError: String?

    let phrase: SavedPhrase

    init(phrase: SavedPhrase) {
        self.phrase = phrase
        _audioData = State(initialValue: phrase.audioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phrase") {
                    Text(phrase.text)
                        .font(.title3.weight(.medium))
                    Text("The text remains available for sharing and the system voice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Your recorded voice") {
                    Text("Record this phrase or choose an audio file. The recording plays when you tap the phrase; removing it restores the system voice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(recorder.isRecording ? "Stop recording" : "Record a voice",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording {
                            if let data = recorder.stop(), (try? AVAudioPlayer(data: data)) != nil {
                                audioData = data
                                importError = nil
                            } else {
                                importError = "The recording could not be saved. Try again or import an audio file."
                            }
                        } else {
                            Task { await recorder.start() }
                        }
                    }
                    .accessibilityIdentifier("phrase-record-toggle")
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    Button("Import audio from Files", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                    .disabled(recorder.isRecording)
                    if let audioData {
                        Button("Play preview", systemImage: "play.fill") { store.playRecorded(audioData) }
                            .disabled(recorder.isRecording)
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                            .disabled(recorder.isRecording)
                    }
                    if audioData == nil, let errorMessage = recorder.errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                    if let importError {
                        Text(importError).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Phrase voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updatePhraseRecording(phrase, audioData: audioData)
                        dismiss()
                    }
                    .disabled(recorder.isRecording)
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        guard !data.isEmpty, (try? AVAudioPlayer(data: data)) != nil else {
                            importError = "This audio file could not be played. Choose another file."
                            return
                        }
                        audioData = data
                        importError = nil
                    } catch {
                        importError = error.localizedDescription
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .onDisappear { recorder.discard() }
        }
    }
}
