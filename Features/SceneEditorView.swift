import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SceneEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let board: VisualSceneBoard?
    @State private var title: String
    @State private var pastingPhoto = false
    @State private var imageData: Data?
    @State private var videoData: Data?
    @State private var hotspots: [SceneHotspot]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingPhotoImporter = false
    @State private var showingVideoImporter = false
    @State private var showingHotspotVideoImporter = false
    @State private var hotspotVideoImportID: UUID?
    @State private var preparingVideo = false
    @State private var preparingHotspotVideoID: UUID?
    @State private var recognizingPhotoWords = false
    @State private var photoWordReview: PhotoBoardReview?
    @State private var showingWordPicker = false
    @State private var customWord = ""
    @State private var errorMessage: String?
    @State private var expandedHotspotIDs: Set<UUID> = []
    @State private var recordingHotspot: SceneHotspot?

    init(board: VisualSceneBoard?) {
        self.board = board
        _title = State(initialValue: board?.title ?? "")
        _imageData = State(initialValue: board?.imageData)
        _videoData = State(initialValue: board?.videoData)
        _hotspots = State(initialValue: board?.hotspots ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scene name") {
                    TextField("Kitchen, playground, or family", text: $title)
                        .accessibilityIdentifier("scene-title")
                }
                Section("Photo or video") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose or change photo", systemImage: "photo")
                    }
                    .disabled(preparingVideo)
                    PictureLibraryPickerButton(title: "Picture library",
                                               identifier: "scene-picture-library") { picture in
                        imageData = picture.imageData
                        videoData = nil
                    }
                    .disabled(preparingVideo)
                    CameraPhotoButton { imageData = $0; videoData = nil }
                        .disabled(preparingVideo)
                    PastePhotoButton(identifier: "scene-paste-photo", onPastingChange: { pastingPhoto = $0 }) {
                        imageData = $0
                        videoData = nil
                    }
                    .disabled(preparingVideo)
                    Button("Choose photo from Files", systemImage: "folder") {
                        showingPhotoImporter = true
                    }
                    .accessibilityIdentifier("scene-import-photo-file")
                    .disabled(preparingVideo)
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("Choose video from Photos", systemImage: "video")
                    }
                    .disabled(preparingVideo)
                    Button("Choose video from Files", systemImage: "film") {
                        showingVideoImporter = true
                    }
                    .accessibilityIdentifier("scene-import-video-file")
                    .disabled(preparingVideo)
                    if preparingVideo {
                        ProgressView("Preparing video")
                    }
                    if videoData != nil {
                        Label("Video scene: position words on its first frame.", systemImage: "play.rectangle")
                            .font(.footnote)
                        Button("Use still frame as photo") { videoData = nil }
                    }
                    if let imageData {
                        ScenePhotoCanvas(imageData: imageData, hotspots: hotspots) { hotspot, size in
                            SceneMarkerLabel(label: label(for: hotspot), highContrast: store.settings.highContrast,
                                             width: hotspot.width.map { $0 * size.width },
                                             height: hotspot.height.map { $0 * size.height },
                                             backgroundColorHex: hotspot.backgroundColorHex)
                                .gesture(DragGesture(coordinateSpace: .named("sceneCanvas"))
                                    .onChanged { drag in move(hotspot.id, to: drag.location, in: size) })
                                .accessibilityLabel("\(label(for: hotspot)). Drag to move; position controls below.")
                        }
                        .coordinateSpace(name: "sceneCanvas")
                        .accessibilityIdentifier("scene-photo-preview")
                        if videoData == nil && hotspots.count < 12 {
                            Button("Find words in photo", systemImage: "text.viewfinder") {
                                findWords(in: imageData)
                            }
                            .accessibilityIdentifier("scene-find-photo-words")
                            .disabled(recognizingPhotoWords || preparingVideo)
                            Text("Review recognized text before adding it. Existing markers stay in place.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if recognizingPhotoWords { ProgressView("Reading photo") }
                    } else {
                        Text("Choose a familiar photo or short video for the communicator.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Words on scene (\(hotspots.count) of 12)") {
                    ForEach(hotspots) { hotspot in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(label(for: hotspot)).font(.headline)
                                Spacer()
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    hotspots.removeAll { $0.id == hotspot.id }
                                }
                                .labelStyle(.iconOnly)
                                .accessibilityLabel("Remove \(label(for: hotspot))")
                            }
                            HStack(spacing: 12) {
                                moveButton("Left", "arrow.left", id: hotspot.id, dx: -0.05, dy: 0)
                                moveButton("Up", "arrow.up", id: hotspot.id, dx: 0, dy: -0.05)
                                moveButton("Down", "arrow.down", id: hotspot.id, dx: 0, dy: 0.05)
                                moveButton("Right", "arrow.right", id: hotspot.id, dx: 0.05, dy: 0)
                            }
                            Menu {
                                Button(hotspot.videoData == nil ? "Say this word" : "Replace video with speech",
                                       systemImage: "speaker.wave.2") {
                                    setDestination(nil, for: hotspot.id)
                                }
                                ForEach(store.sceneBoards.filter { $0.id != board?.id }) { scene in
                                    Button(hotspot.videoData == nil ? "Open \(scene.title)" :
                                           "Replace video and open \(scene.title)",
                                           systemImage: "arrow.right.circle") {
                                        setDestination(scene.id, for: hotspot.id)
                                    }
                                }
                            } label: {
                                Label(actionDescription(for: hotspot), systemImage: "arrow.triangle.branch")
                            }
                            .accessibilityIdentifier("scene-action-\(hotspot.id)")
                            Button {
                                if expandedHotspotIDs.contains(hotspot.id) {
                                    expandedHotspotIDs.remove(hotspot.id)
                                } else {
                                    expandedHotspotIDs.insert(hotspot.id)
                                }
                            } label: {
                                HStack {
                                    Text("Size, color, voice, and video")
                                    Spacer()
                                    Image(systemName: expandedHotspotIDs.contains(hotspot.id)
                                          ? "chevron.up" : "chevron.down")
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Customize \(label(for: hotspot))")
                            .accessibilityValue(expandedHotspotIDs.contains(hotspot.id) ? "Expanded" : "Collapsed")
                            if expandedHotspotIDs.contains(hotspot.id) {
                                hotspotControls(for: hotspot)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if hotspots.count < 12 {
                        Button("Add from my words", systemImage: "plus") { showingWordPicker = true }
                            .accessibilityIdentifier("add-scene-word")
                        HStack {
                            TextField("Or type a word or phrase", text: $customWord)
                                .accessibilityIdentifier("scene-custom-word")
                            Button("Add") { addCustomWord() }
                                .disabled(customWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    Text("Drag a word on the scene, or use the direction buttons to place it precisely.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(board == nil ? "New scene" : "Edit scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  imageData == nil || hotspots.isEmpty || preparingVideo || pastingPhoto ||
                                  preparingHotspotVideoID != nil)
                        .accessibilityIdentifier("save-scene")
                }
            }
            .sheet(isPresented: $showingWordPicker) {
                SceneWordPickerView { item in addWord(item) }
            }
            .sheet(item: $recordingHotspot) { hotspot in
                SceneHotspotVoiceEditor(label: label(for: hotspot),
                                        audioData: hotspot.recordedAudioData) { data in
                    updateHotspot(hotspot.id) { $0.recordedAudioData = data }
                }
            }
            .sheet(item: $photoWordReview) { review in
                PhotoBoardWordsReviewView(words: review.words, availableSlots: 12 - hotspots.count) { selected in
                    for word in selected {
                        let option = ChoiceOption(label: word.text)
                        hotspots.append(SceneHotspot(option: option, x: word.x, y: word.y,
                                                     width: word.width, height: word.height))
                    }
                    photoWordReview = nil
                }
            }
            .fileImporter(isPresented: $showingPhotoImporter, allowedContentTypes: [.image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        guard let prepared = try await PhotoProcessing.preparedDataAsync(fromFile: url) else {
                            errorMessage = "This file is not a usable image. Choose another photo."
                            return
                        }
                        imageData = prepared
                        videoData = nil
                    } catch {
                        errorMessage = "Could not open that image. Choose another photo or file."
                    }
                }
            }
            .fileImporter(isPresented: $showingVideoImporter, allowedContentTypes: [.movie]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    preparingVideo = true
                    Task {
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        await prepareVideo(from: url)
                    }
                } catch {
                    errorMessage = "Could not open that video. Choose another clip."
                }
            }
            .fileImporter(isPresented: $showingHotspotVideoImporter, allowedContentTypes: [.movie]) { result in
                guard let id = hotspotVideoImportID else { return }
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    preparingHotspotVideoID = id
                    Task {
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        await prepareHotspotVideo(from: url, for: id)
                    }
                } catch {
                    errorMessage = "Could not open that video. Choose another clip."
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        let data = try await photo.loadTransferable(type: Data.self)
                        guard let data, let prepared = await PhotoProcessing.preparedDataAsync(from: data) else {
                            errorMessage = "Could not open that photo. Try another photo or choose an image from Files."
                            return
                        }
                        imageData = prepared
                        videoData = nil
                    } catch {
                        errorMessage = "Could not open that photo. Try another photo or choose an image from Files."
                    }
                }
            }
            .onChange(of: selectedVideo) { _, video in
                guard let video else { return }
                preparingVideo = true
                Task {
                    do {
                        guard let file = try await video.loadTransferable(type: SceneVideoFile.self) else {
                            throw SceneVideoError.unusableVideo
                        }
                        defer { try? FileManager.default.removeItem(at: file.url) }
                        await prepareVideo(from: file.url)
                    } catch {
                        preparingVideo = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .alert("Scene problem", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Check the scene name, photo, and words.")
            }
        }
    }

    private func label(for hotspot: SceneHotspot) -> String {
        store.displayLabel(for: hotspot.option.resolved(using: store.items).communicationItem)
    }

    private func actionDescription(for hotspot: SceneHotspot) -> String {
        if hotspot.videoData != nil { return "Plays attached video" }
        guard let id = hotspot.destinationSceneID else { return "Says this word" }
        guard let target = store.sceneBoards.first(where: { $0.id == id }) else {
            return "Linked scene unavailable"
        }
        return "Opens \(target.title)"
    }

    private func setDestination(_ id: UUID?, for hotspotID: UUID) {
        updateHotspot(hotspotID) {
            $0.destinationSceneID = id
            $0.videoData = nil
            $0.videoPosterData = nil
            if id != nil { $0.recordedAudioData = nil }
        }
    }

    @ViewBuilder
    private func hotspotControls(for hotspot: SceneHotspot) -> some View {
        let id = hotspot.id
        VStack(alignment: .leading, spacing: 10) {
            if !store.items.contains(where: { $0.id == hotspot.option.id }) {
                TextField("Marker label", text: Binding(
                    get: { hotspots.first(where: { $0.id == id })?.option.label ?? "" },
                    set: { value in
                        updateHotspot(id) {
                            if $0.option.message == $0.option.label { $0.option.message = value }
                            $0.option.label = value
                        }
                    }
                ))
                .accessibilityIdentifier("scene-marker-label-\(id)")
            }
            HStack {
                Text("Width")
                Slider(value: Binding(
                    get: { hotspots.first(where: { $0.id == id })?.width ?? 0.28 },
                    set: { value in updateHotspot(id) { $0.width = value; $0.height = $0.height ?? 0.16 } }
                ), in: 0.12...0.8)
                .accessibilityIdentifier("scene-width-\(id)")
            }
            HStack {
                Text("Height")
                Slider(value: Binding(
                    get: { hotspots.first(where: { $0.id == id })?.height ?? 0.16 },
                    set: { value in updateHotspot(id) { $0.height = value; $0.width = $0.width ?? 0.28 } }
                ), in: 0.08...0.5)
                .accessibilityIdentifier("scene-height-\(id)")
            }
            if hotspot.width != nil || hotspot.height != nil {
                Button("Use automatic size") {
                    updateHotspot(id) { $0.width = nil; $0.height = nil }
                }
            }
            ColorPicker("Marker color", selection: Binding(
                get: {
                    guard let hex = hotspots.first(where: { $0.id == id })?.backgroundColorHex,
                          let value = ButtonColorValue(text: hex) else { return .white }
                    return ButtonColorAppearance.color(value)
                },
                set: { color in updateHotspot(id) { $0.backgroundColorHex = ButtonColorAppearance.hex(from: color) } }
            ))
            .accessibilityIdentifier("scene-color-\(id)")
            if hotspot.backgroundColorHex != nil {
                Button("Use default color") { updateHotspot(id) { $0.backgroundColorHex = nil } }
            }
            Toggle("Show label on marker", isOn: Binding(
                get: { hotspots.first(where: { $0.id == id })?.showsLabel != false },
                set: { value in updateHotspot(id) { $0.showsLabel = value } }
            ))
            .accessibilityIdentifier("scene-show-label-\(id)")
            if hotspot.destinationSceneID == nil && hotspot.videoData == nil {
                Button(hotspot.recordedAudioData == nil ? "Record personal voice" : "Edit personal voice",
                       systemImage: "mic.fill") {
                    recordingHotspot = hotspot
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("scene-record-voice-\(id)")
                if hotspot.recordedAudioData != nil {
                    Label("Personal voice attached", systemImage: "waveform")
                        .foregroundStyle(.secondary)
                }
            }
            hotspotVideoControls(for: hotspot)
            TextField("Spoken text (uses word by default)", text: Binding(
                get: { hotspots.first(where: { $0.id == id })?.spokenText ?? "" },
                set: { value in
                    updateHotspot(id) {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        $0.spokenText = trimmed.isEmpty ? nil : value
                    }
                }
            ))
            .accessibilityIdentifier("scene-spoken-text-\(id)")
            .disabled(hotspot.videoData != nil)
            Picker("When tapped", selection: Binding(
                get: { hotspots.first(where: { $0.id == id })?.effectiveBehavior ?? .speakAndAdd },
                set: { value in updateHotspot(id) { $0.behavior = value } }
            )) {
                ForEach(SceneHotspotBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.title).tag(behavior)
                }
            }
            .accessibilityIdentifier("scene-behavior-\(id)")
            .disabled(hotspot.videoData != nil)
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private func hotspotVideoControls(for hotspot: SceneHotspot) -> some View {
        let id = hotspot.id
        if let poster = hotspot.videoPosterData {
            HStack {
                AsyncThumbnailImage(data: poster, maxPixelSize: 200) {
                    Image(systemName: "video").font(.title)
                }
                    .frame(width: 80, height: 60)
                    .clipped()
                Text("This marker plays its video when tapped.")
            }
            Button("Remove attached video", role: .destructive) {
                updateHotspot(id) { $0.videoData = nil; $0.videoPosterData = nil }
            }
            .accessibilityIdentifier("scene-remove-hotspot-video-\(id)")
        } else {
            SceneHotspotVideoPicker(label: label(for: hotspot), onBusy: {
                preparingHotspotVideoID = id
            }, onPick: { file in
                Task {
                    defer { try? FileManager.default.removeItem(at: file.url) }
                    await prepareHotspotVideo(from: file.url, for: id)
                }
            }, onError: { error in
                preparingHotspotVideoID = nil
                errorMessage = error.localizedDescription
            })
            .disabled(preparingHotspotVideoID != nil || preparingVideo)
            Button("Attach video from Files", systemImage: "film") {
                hotspotVideoImportID = id
                showingHotspotVideoImporter = true
            }
            .accessibilityIdentifier("scene-attach-hotspot-video-file-\(id)")
            .disabled(preparingHotspotVideoID != nil || preparingVideo)
            if preparingHotspotVideoID == id { ProgressView("Preparing attached video") }
        }
    }

    private func updateHotspot(_ id: UUID, _ update: (inout SceneHotspot) -> Void) {
        guard let index = hotspots.firstIndex(where: { $0.id == id }) else { return }
        update(&hotspots[index])
        hotspots[index] = hotspots[index].moved(toX: hotspots[index].x, y: hotspots[index].y)
    }

    private func findWords(in sourceData: Data) {
        recognizingPhotoWords = true
        Task {
            do {
                let found = try await Task.detached(priority: .userInitiated) {
                    try PhotoBoardRecognition.recognize(imageData: sourceData)
                }.value
                if imageData == sourceData { photoWordReview = PhotoBoardReview(words: found) }
            } catch {
                if imageData == sourceData { errorMessage = error.localizedDescription }
            }
            recognizingPhotoWords = false
        }
    }

    private func addWord(_ item: CommunicationItem) {
        guard hotspots.count < 12 else { return }
        let option = ChoiceOption(id: item.id, label: item.label, symbol: item.symbol,
                                  message: item.message, audioData: item.audioData)
        let position = nextPosition()
        hotspots.append(SceneHotspot(option: option, x: position.x, y: position.y))
    }

    private func addCustomWord() {
        let word = customWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, hotspots.count < 12 else { return }
        let position = nextPosition()
        hotspots.append(SceneHotspot(option: ChoiceOption(label: word), x: position.x, y: position.y))
        customWord = ""
    }

    private func nextPosition() -> (x: Double, y: Double) {
        let index = hotspots.count
        return (0.25 + Double(index % 3) * 0.25,
                0.2 + Double(index / 3) * 0.2)
    }

    private func move(_ id: UUID, to point: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0, let index = hotspots.firstIndex(where: { $0.id == id }) else { return }
        hotspots[index] = hotspots[index].moved(toX: min(0.85, max(0.15, point.x / size.width)),
                                                  y: min(0.9, max(0.1, point.y / size.height)))
    }

    private func moveButton(_ title: String, _ symbol: String, id: UUID, dx: Double, dy: Double) -> some View {
        Button(title, systemImage: symbol) {
            guard let index = hotspots.firstIndex(where: { $0.id == id }) else { return }
            hotspots[index] = hotspots[index].moved(toX: min(0.85, max(0.15, hotspots[index].x + dx)),
                                                      y: min(0.9, max(0.1, hotspots[index].y + dy)))
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .accessibilityLabel("Move \(hotspots.first(where: { $0.id == id })?.option.label ?? "word") \(title.lowercased())")
    }

    private func prepareVideo(from url: URL) async {
        do {
            let prepared = try await SceneVideoProcessing.prepared(from: url)
            let attachedBytes = hotspots.reduce(0) {
                $0 + ($1.videoData?.count ?? 0) + ($1.videoPosterData?.count ?? 0)
            }
            guard prepared.video.count + prepared.poster.count + attachedBytes <=
                SceneVideoProcessing.maxSceneBytes else {
                throw SceneVideoError.sceneTooLarge
            }
            imageData = prepared.poster
            videoData = prepared.video
        } catch {
            errorMessage = error.localizedDescription
        }
        preparingVideo = false
    }

    private func prepareHotspotVideo(from url: URL, for id: UUID) async {
        do {
            let prepared = try await SceneVideoProcessing.prepared(
                from: url, byteLimit: SceneVideoProcessing.maxHotspotBytes)
            let otherMediaBytes = (imageData?.count ?? 0) + (videoData?.count ?? 0) +
                hotspots.filter { $0.id != id }.reduce(0) {
                    $0 + ($1.videoData?.count ?? 0) + ($1.videoPosterData?.count ?? 0)
                }
            guard otherMediaBytes + prepared.video.count + prepared.poster.count <=
                SceneVideoProcessing.maxSceneBytes else {
                throw SceneVideoError.sceneTooLarge
            }
            updateHotspot(id) {
                $0.destinationSceneID = nil
                $0.recordedAudioData = nil
                $0.videoData = prepared.video
                $0.videoPosterData = prepared.poster
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        preparingHotspotVideoID = nil
    }

    private func save() {
        guard let imageData else { return }
        let saved = VisualSceneBoard(id: board?.id ?? UUID(), title: title,
                                     imageData: imageData, hotspots: hotspots, videoData: videoData)
        if store.saveSceneBoard(saved) { dismiss() }
        else { errorMessage = "Choose a unique scene name and check each word." }
    }
}

private struct PhotoBoardReview: Identifiable {
    let id = UUID()
    let words: [PhotoBoardWord]
}

private struct PhotoBoardWordsReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var words: [PhotoBoardWord]
    @State private var selectedIDs: Set<UUID>
    let availableSlots: Int
    let onAdd: ([PhotoBoardWord]) -> Void

    init(words: [PhotoBoardWord], availableSlots: Int, onAdd: @escaping ([PhotoBoardWord]) -> Void) {
        _words = State(initialValue: words)
        _selectedIDs = State(initialValue: Set(words.prefix(availableSlots).map(\.id)))
        self.availableSlots = availableSlots
        self.onAdd = onAdd
    }

    private var selectedWords: [PhotoBoardWord] {
        words.filter { selectedIDs.contains($0.id) }.compactMap { word in
            var edited = word
            edited.text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return edited.text.isEmpty ? nil : edited
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Check the recognized words here. After adding them, review and move their markers on the photo before saving.")
                        .foregroundStyle(.secondary)
                    Text("\(availableSlots) marker spaces available")
                        .font(.subheadline.weight(.semibold))
                }
                Section("Words found") {
                    ForEach($words) { $word in
                        HStack {
                            Toggle("Include \(word.text)", isOn: Binding(
                                get: { selectedIDs.contains(word.id) },
                                set: { include in
                                    if include && selectedIDs.count < availableSlots {
                                        selectedIDs.insert(word.id)
                                    } else if !include {
                                        selectedIDs.remove(word.id)
                                    }
                                }
                            ))
                            .labelsHidden()
                            .disabled(!selectedIDs.contains(word.id) && selectedIDs.count >= availableSlots)
                            TextField("Recognized word", text: $word.text)
                                .accessibilityIdentifier("photo-board-word-\(word.id)")
                        }
                    }
                }
            }
            .navigationTitle("Review photo words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedWords.count) words") {
                        onAdd(selectedWords)
                    }
                    .disabled(selectedWords.isEmpty)
                    .accessibilityIdentifier("add-reviewed-photo-words")
                }
            }
        }
    }
}

private struct SceneHotspotVideoPicker: View {
    let label: String
    let onBusy: () -> Void
    let onPick: (SceneVideoFile) -> Void
    let onError: (Error) -> Void
    @State private var selectedVideo: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedVideo, matching: .videos) {
            Label("Attach video from Photos", systemImage: "video.badge.plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Attach video to \(label) from Photos")
        .onChange(of: selectedVideo) { _, item in
            guard let item else { return }
            onBusy()
            Task {
                do {
                    guard let file = try await item.loadTransferable(type: SceneVideoFile.self) else {
                        throw SceneVideoError.unusableVideo
                    }
                    onPick(file)
                } catch { onError(error) }
                selectedVideo = nil
            }
        }
    }
}

private struct SceneHotspotVoiceEditor: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var audioData: Data?
    @State private var isPreparing = false
    @State private var errorMessage: String?

    let label: String
    let onSave: (Data?) -> Void

    init(label: String, audioData: Data?, onSave: @escaping (Data?) -> Void) {
        self.label = label
        self.onSave = onSave
        _audioData = State(initialValue: audioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scene word") {
                    Text(label).font(.title3.weight(.medium))
                    Text("A personal voice plays when this marker speaks. Its words still appear in the message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Personal voice") {
                    Button(recorder.isRecording ? "Stop recording" : "Record a voice",
                           systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if recorder.isRecording {
                            guard let data = recorder.stop(), !data.isEmpty,
                                  data.count <= 10 * 1_048_576,
                                  (try? AVAudioPlayer(data: data)) != nil else {
                                errorMessage = "The recording could not be saved. Try again."
                                return
                            }
                            audioData = data
                            errorMessage = nil
                        } else {
                            isPreparing = true
                            Task {
                                await recorder.start()
                                isPreparing = false
                            }
                        }
                    }
                    .disabled(isPreparing)
                    .accessibilityIdentifier("scene-voice-record-toggle")
                    if isPreparing { ProgressView("Preparing microphone") }
                    if recorder.isRecording {
                        Label("Recording", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    if let audioData {
                        Button("Play preview", systemImage: "play.fill") {
                            store.playRecorded(audioData)
                        }
                        .disabled(recorder.isRecording || isPreparing)
                        .accessibilityIdentifier("scene-voice-preview")
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                            .disabled(recorder.isRecording || isPreparing)
                            .accessibilityIdentifier("scene-voice-remove")
                    }
                    if let error = errorMessage ?? recorder.errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Scene voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(audioData)
                        dismiss()
                    }
                    .disabled(recorder.isRecording || isPreparing)
                    .accessibilityIdentifier("scene-voice-save")
                }
            }
            .onDisappear { recorder.discard() }
        }
    }
}
