import AVFAudio
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RoutineStepEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioMessageRecorder()

    let step: RoutineStep?
    @State private var title: String
    @State private var pastingPhoto = false
    @State private var symbol: String
    @State private var spokenText: String
    @State private var durationSeconds: Int
    @State private var imageData: Data?
    @State private var videoData: Data?
    @State private var videoPosterData: Data?
    @State private var choiceBoardID: UUID?
    @State private var audioData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingImageImporter = false
    @State private var showingVideoImporter = false
    @State private var showingAudioImporter = false
    @State private var showingChoiceBoards = false
    @State private var preparingVideo = false
    @State private var mediaError: String?
    @State private var errorMessage: String?

    init(step: RoutineStep?) {
        self.step = step
        _title = State(initialValue: step?.title ?? "")
        _symbol = State(initialValue: step?.symbol ?? "⭐️")
        _spokenText = State(initialValue: step?.spokenText ?? "")
        _durationSeconds = State(initialValue: step?.durationSeconds ?? 0)
        _imageData = State(initialValue: step?.imageData)
        _videoData = State(initialValue: step?.videoData)
        _videoPosterData = State(initialValue: step?.videoPosterData)
        _choiceBoardID = State(initialValue: step?.choiceBoardID)
        _audioData = State(initialValue: step?.audioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step") {
                    TextField("What happens next?", text: $title)
                        .accessibilityIdentifier("routine-step-title")
                    TextField("Emoji or symbol", text: $symbol)
                    TextField("Words to say (optional)", text: $spokenText)
                        .accessibilityIdentifier("routine-step-spoken-text")
                    Text("If the spoken words are empty, the step name is spoken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Picture or video") {
                    if videoData == nil {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose a photo", systemImage: "photo")
                        }
                        PictureLibraryPickerButton(title: "Picture library",
                                                   identifier: "routine-step-picture-library") { picture in
                            imageData = picture.imageData
                            videoData = nil
                            videoPosterData = nil
                        }
                        CameraPhotoButton {
                            imageData = $0
                            videoData = nil
                            videoPosterData = nil
                        }
                        PastePhotoButton(identifier: "routine-step-paste-photo", onPastingChange: { pastingPhoto = $0 }) {
                            imageData = $0
                            videoData = nil
                            videoPosterData = nil
                        }
                        Button("Choose photo from Files", systemImage: "folder") {
                            showingImageImporter = true
                        }
                        if let imageData {
                            AsyncThumbnailImage(data: imageData, maxPixelSize: 400, contentMode: .fit) {
                                Text(symbol).font(.largeTitle)
                            }
                                .frame(maxHeight: 180)
                            Button("Remove photo", role: .destructive) { self.imageData = nil }
                        }
                    }
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("Choose video from Photos", systemImage: "video.badge.plus")
                    }
                    .disabled(preparingVideo)
                    Button("Choose video from Files", systemImage: "folder") {
                        showingVideoImporter = true
                    }
                    .disabled(preparingVideo)
                    if preparingVideo { ProgressView("Preparing video") }
                    if let videoPosterData {
                        AsyncThumbnailImage(data: videoPosterData, maxPixelSize: 400, contentMode: .fit) {
                            Image(systemName: "video").font(.largeTitle)
                        }
                            .frame(maxHeight: 180)
                    }
                    if videoData != nil {
                        Button("Remove video", role: .destructive) {
                            videoData = nil
                            videoPosterData = nil
                        }
                    }
                    Text("The first frame appears on the routine and its PDF. Videos are limited to one minute and 8 MB after compression.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let mediaError { Text(mediaError).foregroundStyle(.red) }
                }
                Section("Choice board") {
                    Picker("Open choices", selection: $choiceBoardID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(store.choiceBoards) { board in
                            Text(board.title).tag(Optional(board.id))
                        }
                    }
                    .accessibilityIdentifier("routine-step-choice-board")
                    Button("Manage choice boards", systemImage: "square.grid.2x2") {
                        showingChoiceBoards = true
                    }
                    Text("A saved choice board opens from this step without marking it done.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Spoken instruction") {
                    Button(recorder.isRecording ? "Stop recording" : "Record instruction",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording {
                            if let data = recorder.stop(), (try? AVAudioPlayer(data: data)) != nil {
                                audioData = data
                                errorMessage = nil
                            } else {
                                errorMessage = "The recording could not be saved. Try again or import audio."
                            }
                        } else {
                            Task { await recorder.start() }
                        }
                    }
                    .accessibilityIdentifier("routine-record-toggle")
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    Button("Import instruction from Files", systemImage: "square.and.arrow.down") {
                        showingAudioImporter = true
                    }
                    .disabled(recorder.isRecording)
                    if let audioData {
                        Button("Play instruction", systemImage: "play.fill") {
                            store.playRecorded(audioData)
                        }
                        .disabled(recorder.isRecording)
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                            .disabled(recorder.isRecording)
                    }
                    Text("Without a recording, the system voice reads the step's spoken words.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let error = errorMessage ?? recorder.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
                Section("Time") {
                    Picker("Time limit", selection: $durationSeconds) {
                        Text("No timer").tag(0)
                        ForEach(RoutineStep.availableDurations, id: \.self) { seconds in
                            Text("\(seconds / 60) min").tag(seconds)
                        }
                    }
                }
            }
            .navigationTitle(step == nil ? "Add routine step" : "Edit routine step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recorder.isRecording || preparingVideo || pastingPhoto)
                        .accessibilityIdentifier("save-routine-step")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self),
                              let prepared = await PhotoProcessing.preparedDataAsync(from: data) else {
                            mediaError = "Could not open that photo. Try Files or another photo."
                            return
                        }
                        imageData = prepared
                        videoData = nil
                        videoPosterData = nil
                        mediaError = nil
                    } catch { mediaError = error.localizedDescription }
                }
            }
            .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    Task {
                        do {
                            guard let prepared = try await PhotoProcessing.preparedDataAsync(fromFile: url) else {
                                mediaError = "This file is not a usable image. Choose another photo."
                                return
                            }
                            imageData = prepared
                            videoData = nil
                            videoPosterData = nil
                            mediaError = nil
                        } catch { mediaError = error.localizedDescription }
                    }
                case .failure(let error): mediaError = error.localizedDescription
                }
            }
            .onChange(of: selectedVideo) { _, video in
                guard let video else { return }
                preparingVideo = true
                mediaError = nil
                Task {
                    do {
                        guard let file = try await video.loadTransferable(type: SceneVideoFile.self) else {
                            throw SceneVideoError.unusableVideo
                        }
                        defer { try? FileManager.default.removeItem(at: file.url) }
                        await prepareVideo(from: file.url)
                    } catch {
                        mediaError = error.localizedDescription
                        preparingVideo = false
                    }
                    selectedVideo = nil
                }
            }
            .fileImporter(isPresented: $showingVideoImporter, allowedContentTypes: [.movie]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    preparingVideo = true
                    mediaError = nil
                    Task {
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        await prepareVideo(from: url)
                    }
                } catch { mediaError = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingAudioImporter, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        guard !data.isEmpty, (try? AVAudioPlayer(data: data)) != nil else {
                            errorMessage = "This audio file could not be played. Choose another file."
                            return
                        }
                        audioData = data
                        errorMessage = nil
                    } catch { errorMessage = error.localizedDescription }
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showingChoiceBoards) { ChoiceBoardsView() }
            .onChange(of: store.choiceBoards) { _, boards in
                if let choiceBoardID, !boards.contains(where: { $0.id == choiceBoardID }) {
                    self.choiceBoardID = nil
                }
            }
            .onDisappear { recorder.discard() }
        }
    }

    private func save() {
        var updated = step ?? RoutineStep(title: title, symbol: symbol)
        updated.title = title
        updated.symbol = symbol
        updated.spokenText = spokenText
        updated.durationSeconds = durationSeconds == 0 ? nil : durationSeconds
        updated.imageData = imageData
        updated.videoData = videoData
        updated.videoPosterData = videoPosterData
        updated.choiceBoardID = choiceBoardID
        let newMessage = spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title.trimmingCharacters(in: .whitespacesAndNewlines)
            : spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.audioData = step?.spokenMessage != newMessage && audioData == step?.audioData
            ? nil : audioData
        if store.saveRoutineStep(updated) { dismiss() }
        else { mediaError = "Give the step a name, supported time limit, usable video, and saved choice board." }
    }

    private func prepareVideo(from url: URL) async {
        do {
            let prepared = try await SceneVideoProcessing.prepared(
                from: url, byteLimit: SceneVideoProcessing.maxHotspotBytes)
            videoData = prepared.video
            videoPosterData = prepared.poster
            imageData = nil
            mediaError = nil
        } catch {
            mediaError = error.localizedDescription
        }
        preparingVideo = false
    }
}
