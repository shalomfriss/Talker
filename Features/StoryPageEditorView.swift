import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct StoryPageEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let storyID: UUID
    let page: StoryPage?
    @State private var text: String
    @State private var symbol: String
    @State private var imageData: Data?
    @State private var additionalImageData: [Data]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedAdditionalPhotos: [PhotosPickerItem] = []
    @State private var backgroundStyle: StoryBackgroundStyle
    @State private var backgroundPhotoData: Data?
    @State private var selectedBackgroundPhoto: PhotosPickerItem?
    @State private var videoData: Data?
    @State private var videoPosterData: Data?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingVideoImporter = false
    @State private var preparingVideo = false
    @State private var videoError: String?
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var audioData: Data?
    @State private var showingAudioImporter = false
    @State private var audioError: String?
    @State private var choices: [StoryChoice]

    private var availableTargetPages: [StoryPage] {
        store.stories.first { $0.id == storyID }?.pages.filter { $0.id != page?.id } ?? []
    }

    private var choicesValid: Bool {
        let targets = Set(availableTargetPages.map(\.id))
        return choices.allSatisfy {
            let label = $0.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return !label.isEmpty && label.count <= StoryChoice.maximumLabelLength
                && targets.contains($0.targetPageID)
        }
    }

    init(storyID: UUID, page: StoryPage?) {
        self.storyID = storyID
        self.page = page
        _text = State(initialValue: page?.text ?? "")
        _symbol = State(initialValue: page?.symbol ?? "📖")
        _imageData = State(initialValue: page?.imageData)
        _additionalImageData = State(initialValue: page?.additionalImageData ?? [])
        _backgroundStyle = State(initialValue: page?.backgroundStyle ?? .plain)
        _backgroundPhotoData = State(initialValue: page?.backgroundPhotoData)
        _videoData = State(initialValue: page?.videoData)
        _videoPosterData = State(initialValue: page?.videoPosterData)
        _audioData = State(initialValue: page?.audioData)
        _choices = State(initialValue: page?.choices ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What should this page say?") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .accessibilityLabel("Page text")
                }
                Section("Picture or video") {
                    TextField("Emoji", text: $symbol)
                    if videoData == nil {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose a photo", systemImage: "photo")
                        }
                        CameraPhotoButton {
                            imageData = $0
                            videoData = nil
                            videoPosterData = nil
                        }
                        if let imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                            Button("Remove photo", role: .destructive) {
                                self.imageData = additionalImageData.isEmpty
                                    ? nil : additionalImageData.removeFirst()
                            }
                            if additionalImageData.count < 3 {
                                PhotosPicker(selection: $selectedAdditionalPhotos,
                                             maxSelectionCount: 3 - additionalImageData.count,
                                             matching: .images) {
                                    Label("Add more photos", systemImage: "photo.on.rectangle.angled")
                                }
                                .accessibilityIdentifier("story-add-more-photos")
                                CameraPhotoButton(title: "Take another photo",
                                                  identifier: "story-take-more-photo") {
                                    guard additionalImageData.count < 3 else { return }
                                    additionalImageData.append($0)
                                }
                            }
                            ForEach(additionalImageData.indices, id: \.self) { index in
                                if let preview = UIImage(data: additionalImageData[index]) {
                                    HStack {
                                        Image(uiImage: preview)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 96, height: 76)
                                        Text("Photo \(index + 2)")
                                        Spacer()
                                        Button("Remove", systemImage: "trash", role: .destructive) {
                                            additionalImageData.remove(at: index)
                                        }
                                        .accessibilityIdentifier("story-remove-photo-\(index + 2)")
                                    }
                                }
                            }
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
                    if let poster = videoPosterData, let image = UIImage(data: poster) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                    }
                    if videoData != nil {
                        Button("Remove video", role: .destructive) {
                            videoData = nil
                            videoPosterData = nil
                        }
                    }
                    if let videoError { Text(videoError).foregroundStyle(.red) }
                    Text("The first frame appears in the story and its PDF. Videos are limited to one minute and 8 MB after compression.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Page background") {
                    Picker("Background", selection: $backgroundStyle) {
                        ForEach(StoryBackgroundStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .accessibilityIdentifier("story-background-style")
                    if backgroundStyle == .photo {
                        PhotosPicker(selection: $selectedBackgroundPhoto, matching: .images) {
                            Label("Choose background photo", systemImage: "photo")
                        }
                        .accessibilityIdentifier("story-background-pick-photo")
                        CameraPhotoButton(title: "Take background photo",
                                          identifier: "story-background-camera") {
                            backgroundPhotoData = $0
                        }
                        if backgroundPhotoData != nil {
                            Button("Remove background photo", role: .destructive) {
                                backgroundPhotoData = nil
                            }
                        } else {
                            Text("Choose a background photo before saving.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ZStack {
                        StoryPageBackgroundView(style: backgroundStyle,
                                                photoData: backgroundPhotoData)
                        Text("Page preview")
                            .font(.headline)
                            .padding(10)
                            .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("story-background-preview")
                }
                Section("Your narration") {
                    Text("Record the words on this page in your own voice, or choose an audio file. Without a recording, the system voice reads the page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(recorder.isRecording ? "Stop recording" : "Record narration",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording {
                            if let data = recorder.stop(), (try? AVAudioPlayer(data: data)) != nil {
                                audioData = data
                                audioError = nil
                            } else {
                                audioError = "The recording could not be saved. Try again or import an audio file."
                            }
                        } else {
                            Task { await recorder.start() }
                        }
                    }
                    .accessibilityIdentifier("story-record-toggle")
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    Button("Import narration from Files", systemImage: "square.and.arrow.down") {
                        showingAudioImporter = true
                    }
                    .disabled(recorder.isRecording)
                    if let audioData {
                        Button("Play narration preview", systemImage: "play.fill") { store.playRecorded(audioData) }
                            .disabled(recorder.isRecording)
                        Button("Remove narration", role: .destructive) { self.audioData = nil }
                            .disabled(recorder.isRecording)
                    }
                    if page?.audioData != nil {
                        Text("Changing the page text removes the old recording unless you replace it before saving.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let error = audioError ?? recorder.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
                if page != nil {
                    Section("Reader choices") {
                        Text("Add up to four choices that open another page in this story. Save other pages first so they can be destinations.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach($choices) { $choice in
                            TextField("Choice label", text: $choice.label)
                                .accessibilityIdentifier("story-choice-label-\(choice.id)")
                            Picker("Go to page", selection: $choice.targetPageID) {
                                ForEach(availableTargetPages) { target in
                                    Text(target.text).lineLimit(1).tag(target.id)
                                }
                            }
                            .accessibilityIdentifier("story-choice-target-\(choice.id)")
                            Button("Remove choice", role: .destructive) {
                                choices.removeAll { $0.id == choice.id }
                            }
                        }
                        Button("Add choice", systemImage: "plus") {
                            guard let target = availableTargetPages.first else { return }
                            choices.append(StoryChoice(label: "", targetPageID: target.id))
                        }
                        .disabled(availableTargetPages.isEmpty || choices.count >= StoryChoice.maximumCount)
                        .accessibilityIdentifier("story-add-choice")
                    }
                }
                if let page {
                    Section {
                        Button("Delete page", role: .destructive) {
                            store.deleteStoryPage(storyID: storyID, pageID: page.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(page == nil ? "Add page" : "Edit page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if var page {
                            page.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            page.symbol = symbol.isEmpty ? "📖" : symbol
                            page.imageData = imageData
                            page.additionalImageData = additionalImageData
                            page.backgroundStyle = backgroundStyle
                            page.backgroundPhotoData = backgroundStyle == .photo ? backgroundPhotoData : nil
                            page.videoData = videoData
                            page.videoPosterData = videoPosterData
                            page.audioData = page.text != self.page?.text && audioData == self.page?.audioData
                                ? nil : audioData
                            page.choices = choices
                            store.updateStoryPage(storyID: storyID, page: page)
                        } else {
                            store.addStoryPage(storyID: storyID, text: text, symbol: symbol,
                                               imageData: imageData, audioData: audioData,
                                               videoData: videoData, videoPosterData: videoPosterData,
                                               additionalImageData: additionalImageData,
                                               backgroundStyle: backgroundStyle,
                                               backgroundPhotoData: backgroundStyle == .photo
                                                   ? backgroundPhotoData : nil)
                        }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              recorder.isRecording || preparingVideo || !choicesValid ||
                              (backgroundStyle == .photo && backgroundPhotoData == nil))
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = PhotoProcessing.preparedData(from: data)
                        if imageData != nil {
                            videoData = nil
                            videoPosterData = nil
                        }
                    }
                }
            }
            .onChange(of: selectedAdditionalPhotos) { _, photos in
                guard !photos.isEmpty else { return }
                Task {
                    for photo in photos where additionalImageData.count < 3 {
                        if let data = try? await photo.loadTransferable(type: Data.self),
                           let prepared = PhotoProcessing.preparedData(from: data) {
                            additionalImageData.append(prepared)
                        }
                    }
                    selectedAdditionalPhotos = []
                }
            }
            .onChange(of: selectedBackgroundPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        backgroundPhotoData = PhotoProcessing.preparedData(from: data)
                    }
                }
            }
            .onChange(of: selectedVideo) { _, video in
                guard let video else { return }
                preparingVideo = true
                videoError = nil
                Task {
                    do {
                        guard let file = try await video.loadTransferable(type: SceneVideoFile.self) else {
                            throw SceneVideoError.unusableVideo
                        }
                        defer { try? FileManager.default.removeItem(at: file.url) }
                        await prepareVideo(from: file.url)
                    } catch {
                        videoError = error.localizedDescription
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
                    videoError = nil
                    Task {
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        await prepareVideo(from: url)
                    }
                } catch {
                    videoError = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $showingAudioImporter, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        guard !data.isEmpty, (try? AVAudioPlayer(data: data)) != nil else {
                            audioError = "This audio file could not be played. Choose another file."
                            return
                        }
                        audioData = data
                        audioError = nil
                    } catch { audioError = error.localizedDescription }
                case .failure(let error):
                    audioError = error.localizedDescription
                }
            }
            .onDisappear { recorder.discard() }
        }
    }

    private func prepareVideo(from url: URL) async {
        do {
            let prepared = try await SceneVideoProcessing.prepared(
                from: url, byteLimit: SceneVideoProcessing.maxHotspotBytes)
            videoData = prepared.video
            videoPosterData = prepared.poster
            imageData = nil
            additionalImageData = []
        } catch {
            videoError = error.localizedDescription
        }
        preparingVideo = false
    }
}
