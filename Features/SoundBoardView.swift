import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SoundBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingClip: SoundBoardClip?
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tap a sound to play it once. Personal recordings stay with this profile and its backups.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Ready sounds")
                        .font(.headline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BuiltInSound.allCases) { sound in
                            soundButton(sound.title, symbol: sound.symbol,
                                        identifier: "sound-board-\(sound.id)") {
                                guard let url = sound.fileURL,
                                      let data = try? Data(contentsOf: url) else {
                                    errorMessage = "This sound is unavailable."
                                    return
                                }
                                store.playRecorded(data)
                            }
                        }
                    }

                    HStack {
                        Text("My sounds")
                            .font(.headline)
                        Spacer()
                        Button("Add sound", systemImage: "plus") {
                            editingClip = SoundBoardClip(name: "", audioData: Data())
                        }
                        .disabled(store.settings.soundBoardClips.count >= SoundBoardClip.maximumCount)
                        .accessibilityIdentifier("sound-board-add")
                    }

                    if store.settings.soundBoardClips.isEmpty {
                        Text("Record a familiar sound or import an audio file to make it available here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.settings.soundBoardClips) { clip in
                                soundButton(clip.name, symbol: "waveform",
                                            identifier: "sound-board-custom-\(clip.id)") {
                                    store.playRecorded(clip.audioData)
                                }
                                .contextMenu {
                                    Button("Edit") { editingClip = clip }
                                    Button("Delete", role: .destructive) {
                                        store.settings.soundBoardClips.removeAll { $0.id == clip.id }
                                    }
                                }
                            }
                        }
                    }

                    Button("Stop sound", systemImage: "stop.fill") { store.stopSpeaking() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("sound-board-stop")
                }
                .frame(maxWidth: 620)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Sound board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editingClip) { clip in
                SoundBoardClipEditor(clip: clip)
                    .environmentObject(store)
            }
            .alert("Sound unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: store.activeProfileID) { _, _ in store.stopSpeaking() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { store.stopSpeaking() }
            }
            .onDisappear { store.stopSpeaking() }
        }
    }

    private func soundButton(_ title: String, symbol: String, identifier: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(8)
            .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(title)")
        .accessibilityIdentifier(identifier)
    }
}

private struct SoundBoardClipEditor: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var name: String
    @State private var audioData: Data?
    @State private var showingImporter = false
    @State private var errorMessage: String?

    let clip: SoundBoardClip

    init(clip: SoundBoardClip) {
        self.clip = clip
        _name = State(initialValue: clip.name)
        _audioData = State(initialValue: clip.audioData.isEmpty ? nil : clip.audioData)
    }

    private var canSave: Bool {
        guard let audioData else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.trimmingCharacters(in: .whitespacesAndNewlines).count <= SoundBoardClip.maximumNameLength
            && !audioData.isEmpty && audioData.count <= SoundBoardClip.maximumAudioBytes
            && !recorder.isRecording
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sound name") {
                    TextField("For example, my laugh", text: $name)
                        .accessibilityIdentifier("sound-board-name")
                }
                Section("Recording") {
                    Button(recorder.isRecording ? "Stop recording" : "Record sound",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording {
                            accept(recorder.stop())
                        } else {
                            Task { await recorder.start() }
                        }
                    }
                    .accessibilityIdentifier("sound-board-record")
                    Button("Import audio from Files", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                    .disabled(recorder.isRecording)
                    if let audioData {
                        Button("Play preview", systemImage: "play.fill") { store.playRecorded(audioData) }
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    if let error = recorder.errorMessage { Text(error).foregroundStyle(.red) }
                    Text("Use a short recording up to 2 MB. It is stored only in this profile and its local backups.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(clip.audioData.isEmpty ? "Add sound" : "Edit sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let audioData else { return }
                        let saved = SoundBoardClip(id: clip.id,
                                                   name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                   audioData: audioData)
                        if let index = store.settings.soundBoardClips.firstIndex(where: { $0.id == clip.id }) {
                            store.settings.soundBoardClips[index] = saved
                        } else {
                            store.settings.soundBoardClips.append(saved)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("sound-board-save")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    accept(try? Data(contentsOf: url))
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .onDisappear { recorder.discard(); store.stopSpeaking() }
        }
    }

    private func accept(_ data: Data?) {
        guard let data, !data.isEmpty, data.count <= SoundBoardClip.maximumAudioBytes,
              (try? AVAudioPlayer(data: data)) != nil else {
            errorMessage = "Choose a playable recording smaller than 2 MB."
            return
        }
        audioData = data
        errorMessage = nil
    }
}
