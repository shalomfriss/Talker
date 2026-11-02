import PhotosUI
import SwiftUI

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
                Section("Picture") {
                    TextField("Emoji or symbol", text: $symbol)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose a photo", systemImage: "photo")
                    }
                    Button("Search ARASAAC pictograms", systemImage: "magnifyingglass") {
                        showingPictogramSearch = true
                    }
                    .accessibilityIdentifier("button-search-arasaac")
                    CameraPhotoButton {
                        imageData = $0
                        arasaacPictogramID = nil
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
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
                        if let data = videoPosterData, let image = UIImage(data: data) {
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
                        .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = PhotoProcessing.preparedData(from: data)
                        arasaacPictogramID = nil
                    }
                }
            }
            .sheet(isPresented: $showingPictogramSearch) {
                ARASAACPictogramSearchView(initialQuery: label, language: store.settings.communicationLanguage) {
                    data, id in
                    imageData = data
                    arasaacPictogramID = id
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
                          grammarCategory: grammarCategory)
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
