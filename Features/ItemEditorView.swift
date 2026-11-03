import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ItemEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let item: CommunicationItem?
    @State private var label: String
    @State private var symbol: String
    @State private var message: String
    @State private var spanishLabel: String
    @State private var spanishMessage: String
    @State private var category: String
    @State private var buttonAction: ButtonAction
    @State private var destinationBoard: String
    @State private var destinationSceneID: UUID?
    @State private var imageData: Data?
    @State private var showingPictureLibrary = false
    @State private var pictureLibraryError: String?
    @State private var photoSavedToLibrary = false
    @State private var pastingPhoto = false
    @State private var arasaacPictogramID: Int?
    @State private var showingPictogramSearch = false
    @State private var audioData: Data?
    @State private var videoData: Data?
    @State private var videoPosterData: Data?
    @State private var webURL: String
    @State private var phraseOptions: [CardPhrase]
    @State private var visibility: ButtonVisibility
    @State private var grammarCategory: GrammarCategory?
    @State private var hasCustomBackground: Bool
    @State private var hasCustomBorder: Bool
    @State private var backgroundColor: Color
    @State private var borderColor: Color
    @State private var hasCustomLabelFontSize: Bool
    @State private var labelFontSize: Int
    @State private var hasCustomContentPadding: Bool
    @State private var contentPadding: Int
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingVideoImporter = false
    @State private var preparingVideo = false
    @State private var videoError: String?
    @StateObject private var recorder = AudioMessageRecorder()
    private let isSavingMessage: Bool

    init(item: CommunicationItem?, category: String, initialMessage: String? = nil) {
        self.item = item
        let preparedMessage = initialMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let suggestedLabel = preparedMessage.count > 30
            ? String(preparedMessage.prefix(27)).trimmingCharacters(in: .whitespaces) + "…"
            : preparedMessage
        isSavingMessage = item == nil && initialMessage != nil
        _label = State(initialValue: item?.label ?? suggestedLabel)
        _symbol = State(initialValue: item?.symbol ?? "💬")
        _message = State(initialValue: item?.message ?? preparedMessage)
        _spanishLabel = State(initialValue: "")
        _spanishMessage = State(initialValue: "")
        _category = State(initialValue: item?.category ?? category)
        _buttonAction = State(initialValue: item?.effectiveAction ?? .addToMessage)
        _destinationBoard = State(initialValue: item?.destinationBoard ?? "")
        _destinationSceneID = State(initialValue: item?.destinationSceneID)
        _imageData = State(initialValue: item?.imageData)
        _arasaacPictogramID = State(initialValue: item?.arasaacPictogramID)
        _audioData = State(initialValue: item?.audioData)
        _videoData = State(initialValue: item?.videoData)
        _videoPosterData = State(initialValue: item?.videoPosterData)
        _webURL = State(initialValue: item?.webURL ?? "")
        _phraseOptions = State(initialValue: item?.phraseOptions ?? [])
        _visibility = State(initialValue: item?.boardVisibility ?? .shown)
        _grammarCategory = State(initialValue: item.flatMap(GrammarColorCoding.category(for:)))
        _hasCustomBackground = State(initialValue: item?.backgroundColorHex != nil)
        _hasCustomBorder = State(initialValue: item?.borderColorHex != nil)
        _backgroundColor = State(initialValue: item?.backgroundColorHex
            .flatMap { ButtonColorValue(text: $0) }.map(ButtonColorAppearance.color)
            ?? Color(red: 0.99, green: 0.83, blue: 0.42))
        _borderColor = State(initialValue: item?.borderColorHex
            .flatMap { ButtonColorValue(text: $0) }.map(ButtonColorAppearance.color)
            ?? Color(red: 0.63, green: 0.34, blue: 0.05))
        _hasCustomLabelFontSize = State(initialValue: item?.labelFontSize != nil)
        _labelFontSize = State(initialValue: CommunicationItem.normalizedLabelFontSize(item?.labelFontSize) ?? 16)
        _hasCustomContentPadding = State(initialValue: item?.contentPadding != nil)
        _contentPadding = State(initialValue: CommunicationItem.normalizedContentPadding(item?.contentPadding) ?? 8)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Word or phrase") {
                    TextField("Button label", text: $label)
                    if buttonAction.usesOwnMessage {
                        TextField(buttonAction == .typeText ? "Text to type" : "Spoken message (optional)",
                                  text: $message)
                            .accessibilityIdentifier(buttonAction == .typeText
                                ? "button-typed-text" : "button-spoken-message")
                    }
                    Picker("Category", selection: $category) {
                        ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Button action") {
                    Picker("When tapped", selection: $buttonAction) {
                        ForEach(ButtonAction.allCases, id: \.self) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .accessibilityIdentifier("button-action")
                    buttonActionConfiguration
                }
                if buttonAction == .openWebPage {
                    Section("Web page") {
                        TextField("Website address", text: $webURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("button-web-url")
                        Text("Use a secure https address. An address without a prefix starts with https. The page needs an internet connection.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !webURL.isEmpty && ButtonWebLink.normalized(webURL) == nil {
                            Text("Enter a valid web address.")
                                .foregroundStyle(.red)
                        }
                    }
                }
                Section("Board visibility") {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(ButtonVisibility.allCases, id: \.self) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .accessibilityIdentifier("button-visibility")
                    Text("Hidden buttons leave an empty space, so other buttons stay in place. Dimmed buttons can stay active or be disabled in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Button colors") {
                    Picker("Grammar category", selection: $grammarCategory) {
                        Text("Automatic").tag(GrammarCategory?.none)
                        ForEach(GrammarCategory.allCases) { category in
                            Text(category.title).tag(Optional(category))
                        }
                    }
                    .accessibilityIdentifier("word-grammar-category")
                    Toggle("Custom background", isOn: $hasCustomBackground)
                    if hasCustomBackground {
                        ColorPicker("Background color", selection: $backgroundColor, supportsOpacity: true)
                            .accessibilityIdentifier("button-background-color")
                    }
                    Toggle("Custom border", isOn: $hasCustomBorder)
                    if hasCustomBorder {
                        ColorPicker("Border color", selection: $borderColor, supportsOpacity: true)
                            .accessibilityIdentifier("button-border-color")
                    }
                    Text("The label switches between black and white for contrast. High contrast mode uses black and white buttons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Button text and spacing") {
                    Toggle("Custom label size", isOn: $hasCustomLabelFontSize)
                        .accessibilityIdentifier("button-custom-label-size")
                    if hasCustomLabelFontSize {
                        Stepper("Label size: \(labelFontSize) pt", value: $labelFontSize, in: 12...30)
                            .accessibilityIdentifier("button-label-size")
                    }
                    Toggle("Custom inner spacing", isOn: $hasCustomContentPadding)
                        .accessibilityIdentifier("button-custom-padding")
                    if hasCustomContentPadding {
                        Stepper("Inner spacing: \(contentPadding) pt", value: $contentPadding, in: 0...16)
                            .accessibilityIdentifier("button-content-padding")
                    }
                    Text("These choices affect only this button. Automatic uses the board's button size.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Picture") {
                    TextField("Emoji or symbol", text: $symbol)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose a photo", systemImage: "photo")
                    }
                    Button("Choose from picture library", systemImage: "photo.stack") {
                        showingPictureLibrary = true
                    }
                    .accessibilityIdentifier("button-picture-library")
                    Button("Search ARASAAC pictograms", systemImage: "magnifyingglass") {
                        showingPictogramSearch = true
                    }
                    .accessibilityIdentifier("button-search-arasaac")
                    CameraPhotoButton {
                        imageData = $0
                        arasaacPictogramID = nil
                        photoSavedToLibrary = false
                    }
                    PastePhotoButton(identifier: "button-paste-photo", onPastingChange: { pastingPhoto = $0 }) {
                        imageData = $0
                        arasaacPictogramID = nil
                        photoSavedToLibrary = false
                    }
                    if let imageData {
                        AsyncThumbnailImage(data: imageData, maxPixelSize: 400, contentMode: .fit) {
                            Image(systemName: "photo").font(.largeTitle)
                        }
                            .frame(maxHeight: 180)
                        Button("Remove photo", role: .destructive) {
                            self.imageData = nil
                            arasaacPictogramID = nil
                        }
                        if arasaacPictogramID != nil {
                            Text(ARASAACPictogramService.attribution)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button("Save photo to picture library", systemImage: "square.and.arrow.down") {
                            Task {
                                do {
                                    _ = try await store.addPersonalPicture(imageData,
                                        title: label.isEmpty ? "Picture" : label)
                                    photoSavedToLibrary = true
                                } catch { pictureLibraryError = error.localizedDescription }
                            }
                        }
                        .accessibilityIdentifier("button-save-picture-to-library")
                        .disabled(photoSavedToLibrary)
                        if photoSavedToLibrary {
                            Text("Saved in this profile’s picture library")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if buttonAction == .playVideo {
                    Section("Button video") {
                        PhotosPicker(selection: $selectedVideo, matching: .videos) {
                            Label("Choose video from Photos", systemImage: "video.badge.plus")
                        }
                        .disabled(preparingVideo)
                        Button(videoData == nil ? "Choose video from Files" : "Replace video from Files",
                               systemImage: "folder") {
                            showingVideoImporter = true
                        }
                        .disabled(preparingVideo)
                        if preparingVideo { ProgressView("Preparing video") }
                        if let data = videoPosterData {
                            AsyncThumbnailImage(data: data, maxPixelSize: 400, contentMode: .fit) {
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
                        if let videoError { Text(videoError).foregroundStyle(.red) }
                        Text("The first frame appears on the button. Videos are limited to one minute and 8 MB after compression.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if buttonAction.allowsPhraseOptions {
                    Section("Card phrase choices") {
                        Text("When this card is tapped, choose the word or one of these phrases. A phrase speaks immediately and joins the message.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach($phraseOptions) { $option in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField("Phrase", text: $option.text, axis: .vertical)
                                    Button(role: .destructive) {
                                        phraseOptions.removeAll { $0.id == option.id }
                                    } label: {
                                        Label("Remove phrase", systemImage: "minus.circle.fill")
                                    }
                                    .labelStyle(.iconOnly)
                                }
                                TextField("Spanish phrase (optional)", text: $option.spanishText, axis: .vertical)
                            }
                        }
                        Button("Add phrase", systemImage: "plus") {
                            phraseOptions.append(CardPhrase(text: ""))
                        }
                    }
                }
                if buttonAction.allowsRecording {
                    Section("Recorded voice") {
                        Text(buttonAction == .speakImmediately
                             ? "A recording plays immediately without adding text to the picture message."
                             : "A recording plays when this button is tapped. The full message still uses the selected system voice.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button(recorder.isRecording ? "Stop recording" : "Record a voice",
                               systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                            if recorder.isRecording { audioData = recorder.stop() }
                            else { Task { await recorder.start() } }
                        }
                        if recorder.isRecording {
                            Label("Recording", systemImage: "waveform")
                                .foregroundStyle(.red)
                        }
                        if let audioData {
                            Button("Play recording", systemImage: "play.fill") { store.playRecorded(audioData) }
                            Button("Remove recording", role: .destructive) { self.audioData = nil }
                        }
                        if let errorMessage = recorder.errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                Section("Spanish on the communication board") {
                    TextField("Spanish button label (optional)", text: $spanishLabel)
                    if buttonAction.usesOwnMessage {
                        TextField("Spanish spoken message (optional)", text: $spanishMessage)
                    }
                    Text("Leave the label empty to show this button in English. When the spoken message is empty, the Spanish label is spoken.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if item?.isCustom == true {
                    Section {
                        Button("Delete button", role: .destructive) {
                            if let item { store.deleteItem(item) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? (isSavingMessage ? "Save message as button" : "Add button") : "Edit button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(!canSave || pastingPhoto)
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = await PhotoProcessing.preparedDataAsync(from: data)
                        arasaacPictogramID = nil
                        photoSavedToLibrary = false
                    }
                }
            }
            .sheet(isPresented: $showingPictogramSearch) {
                ARASAACPictogramSearchView(initialQuery: label, language: store.settings.communicationLanguage) {
                    data, id in
                    imageData = data
                    arasaacPictogramID = id
                    photoSavedToLibrary = false
                }
            }
            .sheet(isPresented: $showingPictureLibrary) {
                PersonalPictureLibraryView { picture in
                    imageData = picture.imageData
                    arasaacPictogramID = nil
                    photoSavedToLibrary = false
                }
            }
            .alert("Picture library", isPresented: Binding(
                get: { pictureLibraryError != nil }, set: { if !$0 { pictureLibraryError = nil } }
            )) {
                Button("OK") { pictureLibraryError = nil }
            } message: {
                Text(pictureLibraryError ?? "")
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
            .onChange(of: category) { _, _ in ensureDestination() }
            .onChange(of: buttonAction) { previous, current in
                if symbol == previous.suggestedSymbol { symbol = current.suggestedSymbol }
                ensureDestination()
            }
            .onAppear {
                ensureDestination()
                if let item, let translation = store.translation(for: item) {
                    spanishLabel = translation.label
                    spanishMessage = translation.message
                }
            }
            .onDisappear { recorder.discard() }
        }
    }

    private var canSave: Bool {
        let missingScene = buttonAction.requiresScene &&
            !store.sceneBoards.contains { $0.id == destinationSceneID }
        return !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !recorder.isRecording && !preparingVideo &&
            (buttonAction != .playVideo || videoData != nil) &&
            (buttonAction != .openWebPage || ButtonWebLink.normalized(webURL) != nil) &&
            !missingScene &&
            (!buttonAction.requiresDestination || store.categories.contains(destinationBoard))
    }

    private var messageForSaving: String {
        if buttonAction == .completeTypedPrediction {
            return ["0", "1", "2"].contains(message) ? message : "0"
        }
        return message
    }

    private func saveItem() {
        let destination = buttonAction.requiresDestination ? destinationBoard : nil
        if var item {
            item.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
            item.symbol = symbol
            item.message = messageForSaving.isEmpty ? item.label : messageForSaving
            item.category = category
            item.imageData = imageData
            item.arasaacPictogramID = imageData == nil ? nil : arasaacPictogramID
            item.audioData = buttonAction.allowsRecording ? audioData : nil
            item.videoData = buttonAction == .playVideo ? videoData : nil
            item.videoPosterData = buttonAction == .playVideo ? videoPosterData : nil
            item.webURL = buttonAction == .openWebPage ? webURL : nil
            item.destinationBoard = destination
            item.destinationSceneID = buttonAction.requiresScene ? destinationSceneID : nil
            item.linkBehavior = buttonAction.linkBehavior
            item.action = buttonAction.requiresDestination || buttonAction == .addToMessage
                ? nil : buttonAction
            item.phraseOptions = buttonAction.allowsPhraseOptions
                ? CardPhrase.cleaned(phraseOptions) : nil
            item.visibility = visibility == .shown ? nil : visibility
            item.backgroundColorHex = hasCustomBackground
                ? ButtonColorAppearance.hex(from: backgroundColor) : nil
            item.borderColorHex = hasCustomBorder
                ? ButtonColorAppearance.hex(from: borderColor) : nil
            item.grammarCategory = grammarCategory
            item.labelFontSize = hasCustomLabelFontSize ? labelFontSize : nil
            item.contentPadding = hasCustomContentPadding ? contentPadding : nil
            store.updateItem(item)
            store.updateSpanishTranslation(for: item.id, label: spanishLabel, message: spanishMessage)
        } else {
            store.addItem(label: label, symbol: symbol, message: messageForSaving,
                          category: category, imageData: imageData,
                          arasaacPictogramID: arasaacPictogramID,
                          audioData: buttonAction.allowsRecording ? audioData : nil,
                          videoData: buttonAction == .playVideo ? videoData : nil,
                          videoPosterData: buttonAction == .playVideo ? videoPosterData : nil,
                          webURL: buttonAction == .openWebPage ? webURL : nil,
                          destinationBoard: destination,
                          linkBehavior: buttonAction.linkBehavior,
                          destinationSceneID: buttonAction.requiresScene ? destinationSceneID : nil,
                          action: buttonAction,
                          spanishLabel: spanishLabel, spanishMessage: spanishMessage,
                          phraseOptions: buttonAction.allowsPhraseOptions ? phraseOptions : [],
                          visibility: visibility,
                          backgroundColorHex: hasCustomBackground
                              ? ButtonColorAppearance.hex(from: backgroundColor) : nil,
                          borderColorHex: hasCustomBorder
                              ? ButtonColorAppearance.hex(from: borderColor) : nil,
                          grammarCategory: grammarCategory,
                          labelFontSize: hasCustomLabelFontSize ? labelFontSize : nil,
                          contentPadding: hasCustomContentPadding ? contentPadding : nil)
        }
        dismiss()
    }

    @ViewBuilder
    private var buttonActionConfiguration: some View {
        if buttonAction.requiresDestination {
            Picker("Destination board", selection: $destinationBoard) {
                ForEach(store.categories.filter { $0 != category }, id: \.self) {
                    Text($0).tag($0)
                }
            }
            Text(buttonAction == .visitBoard
                 ? "After one word is chosen, return to the previous board."
                 : "Stay on the destination board until Back or another board is chosen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction.requiresScene {
            if store.sceneBoards.isEmpty {
                Text("Create a scene from the Speak screen before linking a button to it.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Destination scene", selection: $destinationSceneID) {
                    ForEach(store.sceneBoards) { scene in
                        Text(scene.title).tag(Optional(scene.id))
                    }
                }
                .accessibilityIdentifier("button-destination-scene")
                Text("Open this scene without changing the picture message.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if buttonAction == .openKeyboard {
            Text("Show the typing keyboard without changing the picture message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .typeText {
            Text("Insert this button's text into the typed message without leaving the board. Single letters capitalize at the start of a sentence.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .completeTypedPrediction {
            Picker("Suggestion position", selection: Binding(
                get: { ["0", "1", "2"].contains(message) ? message : "0" },
                set: { message = $0 }
            )) {
                ForEach(0..<3) { slot in
                    Text("Suggestion \(slot + 1)").tag(String(slot))
                }
            }
            .accessibilityIdentifier("button-prediction-slot")
            Text("Show this suggestion in a fixed board position and complete the typed word when tapped.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction.isTypingAction {
            Text("Control the typed message while staying on this picture board.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .speakImmediately {
            Text("Speak this button’s message without adding it to the picture message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .speakCurrentTime {
            Text("Speak the current time in the board language without changing either message draft. The time is read when the button is tapped.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .speakMessage {
            Text("Speak the whole picture message that is already on screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .clearMessage {
            Text("Clear the picture message when this button is selected.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .undoClearMessage {
            Text("Restore the last cleared picture message until a new word is added.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .deleteLastEntry {
            Text("Remove only the last picture word or phrase from the message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .backBoard {
            Text("Return to the previous board in this navigation path.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .homeBoard {
            Text("Return to the \(store.homeBoard) home board.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .stopSpeaking {
            Text("Stop the current speech or recording.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .playVideo {
            Text("Open a short video when this button is selected. It does not add a word to the message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if buttonAction == .openWebPage {
            Text("Open a web page inside Open Voice without adding a word to the message.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func ensureDestination() {
        if buttonAction.requiresDestination && (destinationBoard == category || !store.categories.contains(destinationBoard)) {
            destinationBoard = store.categories.first(where: { $0 != category }) ?? ""
        }
        if buttonAction.requiresScene && !store.sceneBoards.contains(where: { $0.id == destinationSceneID }) {
            destinationSceneID = store.sceneBoards.first?.id
        }
    }

    private func prepareVideo(from url: URL) async {
        do {
            let prepared = try await SceneVideoProcessing.prepared(
                from: url, byteLimit: SceneVideoProcessing.maxHotspotBytes)
            videoData = prepared.video
            videoPosterData = prepared.poster
        } catch {
            videoError = error.localizedDescription
        }
        preparingVideo = false
    }
}

struct PersonalPictureLibraryView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (PersonalPicture) -> Void
    @State private var searchText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFiles = false
    @State private var showingTextCreator = false
    @State private var showingStarterGallery = false
    @State private var textPictureContent = ""
    @State private var isLoading = true
    @State private var isAddingPicture = false
    @State private var errorMessage: String?
    @State private var pictureToRename: PersonalPicture?
    @State private var renameDraft = ""
    @State private var pictureToDelete: PersonalPicture?

    private var visiblePictures: [PersonalPicture] {
        guard !searchText.isEmpty else { return store.pictureLibrary }
        return store.pictureLibrary.filter { $0.title.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Photos", systemImage: "photo")
                        }
                        CameraPhotoButton(title: "Camera", identifier: "picture-library-camera") { data in
                            Task { await addPicture(data, title: "Camera photo") }
                        }
                        PastePhotoButton(title: "Paste", identifier: "picture-library-paste") { data in
                            Task { await addPicture(data, title: "Pasted picture") }
                        }
                        Button("Files", systemImage: "folder") { showingFiles = true }
                            .accessibilityIdentifier("picture-library-files")
                        Button("Text or emoji", systemImage: "textformat") {
                            textPictureContent = ""
                            showingTextCreator = true
                        }
                        .accessibilityIdentifier("picture-library-create-text")
                        Button("Starter gallery", systemImage: "square.grid.2x2") {
                            showingStarterGallery = true
                        }
                        .accessibilityIdentifier("picture-library-starter-gallery")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAddingPicture)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal)

                if isLoading || isAddingPicture { ProgressView(isLoading ? "Loading pictures" : "Saving picture") }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                        .accessibilityIdentifier("picture-library-error")
                }
                if !isLoading && store.pictureLibrary.isEmpty {
                    ContentUnavailableView("No saved pictures", systemImage: "photo.stack",
                                           description: Text("Add a picture above, then choose it for this item."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 12) {
                            ForEach(visiblePictures) { picture in pictureCell(picture) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Picture library")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .searchable(text: $searchText, prompt: "Find a picture")
            .task {
                do { try await store.loadPersonalPictures() }
                catch { errorMessage = error.localizedDescription }
                isLoading = false
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self) else {
                            throw PictureLibraryError.invalidPicture
                        }
                        await addPicture(data, title: "Photo")
                    } catch { errorMessage = error.localizedDescription }
                    selectedPhoto = nil
                }
            }
            .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.image]) { result in
                Task {
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try await Task.detached(priority: .userInitiated) {
                            try Data(contentsOf: url)
                        }.value
                        await addPicture(data, title: url.deletingPathExtension().lastPathComponent)
                    } catch { errorMessage = error.localizedDescription }
                }
            }
            .sheet(isPresented: $showingTextCreator) {
                NavigationStack {
                    Form {
                        TextField("Words or emoji", text: $textPictureContent, axis: .vertical)
                            .accessibilityIdentifier("picture-library-text-content")
                        Text("The words or emoji become a picture you can reuse on buttons.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    }
                    .navigationTitle("Create picture")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingTextCreator = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Create") {
                                guard let data = PhotoProcessing.textPictureData(textPictureContent) else {
                                    errorMessage = PictureLibraryError.invalidPicture.localizedDescription
                                    return
                                }
                                Task {
                                    if await addPicture(data, title: textPictureContent) {
                                        showingTextCreator = false
                                    }
                                }
                            }
                            .disabled(textPictureContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingStarterGallery) {
                StarterPictureGalleryView { searchText = "" }
            }
            .alert("Rename picture", isPresented: Binding(
                get: { pictureToRename != nil }, set: { if !$0 { pictureToRename = nil } }
            )) {
                TextField("Picture name", text: $renameDraft)
                Button("Save") {
                    guard let picture = pictureToRename else { return }
                    Task {
                        do { try await store.renamePersonalPicture(picture.id, title: renameDraft) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    pictureToRename = nil
                }
                Button("Cancel", role: .cancel) { pictureToRename = nil }
            }
            .confirmationDialog("Delete picture from library?", isPresented: Binding(
                get: { pictureToDelete != nil }, set: { if !$0 { pictureToDelete = nil } }
            )) {
                Button("Delete picture", role: .destructive) {
                    guard let picture = pictureToDelete else { return }
                    Task {
                        do { try await store.deletePersonalPicture(picture.id) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    pictureToDelete = nil
                }
            } message: {
                Text("Buttons already using this picture keep their own copy.")
            }
        }
    }

    private func pictureCell(_ picture: PersonalPicture) -> some View {
        Button {
            onSelect(picture)
            dismiss()
        } label: {
            VStack(spacing: 6) {
                AsyncThumbnailImage(data: picture.imageData) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                        .frame(height: 108)
                        .frame(maxWidth: .infinity)
                        .clipped()
                Text(picture.title).font(.caption.weight(.medium)).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library-picture-\(picture.title)")
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renameDraft = picture.title
                pictureToRename = picture
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                pictureToDelete = picture
            }
        }
    }

    @discardableResult
    private func addPicture(_ data: Data, title: String) async -> Bool {
        isAddingPicture = true
        defer { isAddingPicture = false }
        do {
            _ = try await store.addPersonalPicture(data, title: title)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private struct StarterPictureGalleryView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onAdded: () -> Void
    @State private var searchText = ""
    @State private var savingPictureID: UUID?
    @State private var errorMessage: String?

    private static let words = StarterVocabulary.items.filter { !$0.symbol.isEmpty }

    private var visibleWords: [CommunicationItem] {
        guard !searchText.isEmpty else { return Self.words }
        return Self.words.filter {
            $0.label.localizedStandardContains(searchText) || $0.category.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Save a starter picture, then tap it in your library to use it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                            .accessibilityIdentifier("starter-gallery-error")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 12) {
                        ForEach(visibleWords) { word in
                            Button {
                                Task { await save(word) }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(word.symbol).font(.system(size: 48))
                                        .frame(height: 62)
                                    Text(word.label).font(.caption.weight(.semibold)).lineLimit(2)
                                    Text(word.category).font(.caption2).foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .disabled(savingPictureID != nil)
                            .accessibilityIdentifier("starter-gallery-\(word.category)-\(word.label)")
                            .accessibilityLabel("\(word.label), \(word.category)")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Starter gallery")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .searchable(text: $searchText, prompt: "Find a starter picture")
            .overlay { if savingPictureID != nil { ProgressView("Saving picture") } }
        }
    }

    private func save(_ word: CommunicationItem) async {
        guard savingPictureID == nil else { return }
        savingPictureID = word.id
        defer { savingPictureID = nil }
        guard let data = PhotoProcessing.symbolPictureData(symbol: word.symbol, label: word.label) else {
            errorMessage = PictureLibraryError.invalidPicture.localizedDescription
            return
        }
        do {
            _ = try await store.addPersonalPicture(data, title: word.label)
            onAdded()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct PictureLibraryPickerButton: View {
    let title: String
    let identifier: String
    let onSelect: (PersonalPicture) -> Void
    @State private var showingLibrary = false

    var body: some View {
        Button(title, systemImage: "photo.on.rectangle.angled") {
            showingLibrary = true
        }
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showingLibrary) {
            PersonalPictureLibraryView(onSelect: onSelect)
        }
    }
}
