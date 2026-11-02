import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhraseTextEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var editedText: String
    @State private var editedLabel: String
    @State private var shortcut: String
    @State private var languageCode: String?
    @State private var tapActionOverride: PhraseTapAction?
    @State private var joinBehavior: PhraseJoinBehavior
    @State private var folderLink: PhraseFolderLink?
    @State private var imageData: Data?
    @State private var arasaacPictogramID: Int?
    @State private var showingPictogramSearch = false
    @State private var colorHex: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImageImporter = false
    @State private var photoError: String?
    @State private var errorText = ""

    let phrase: SavedPhrase

    init(phrase: SavedPhrase) {
        self.phrase = phrase
        _editedText = State(initialValue: phrase.text)
        _editedLabel = State(initialValue: phrase.label ?? "")
        _shortcut = State(initialValue: phrase.shortcut ?? "")
        _languageCode = State(initialValue: phrase.languageCode)
        _tapActionOverride = State(initialValue: phrase.tapActionOverride)
        _joinBehavior = State(initialValue: phrase.joinBehavior)
        _folderLink = State(initialValue: phrase.folderLink)
        _imageData = State(initialValue: phrase.imageData)
        _arasaacPictogramID = State(initialValue: phrase.arasaacPictogramID)
        _colorHex = State(initialValue: phrase.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Phrase text") {
                    TextField("Phrase text", text: $editedText, axis: .vertical)
                        .lineLimit(2...6)
                    Text("Add a named blank in braces, such as: I would like {drink}.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Card label") {
                    TextField("Short label (optional)", text: $editedLabel)
                        .accessibilityIdentifier("phrase-card-label-editor")
                    Text("Show a short name or emoji on the picture card. Speaking, typing, and sharing still use the full phrase above. Up to 40 characters.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Typing shortcut") {
                    TextField("Shortcut (optional)", text: $shortcut)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use 2 to 12 letters or numbers. Type it in Keyboard mode, then tap the suggestion.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Spoken language") {
                    Picker("Speak this phrase with", selection: $languageCode) {
                        Text("Use current voice").tag(String?.none)
                        if let languageCode,
                           !PhraseLanguage.availableCodes.contains(languageCode) {
                            Text("Unavailable on this device (\(languageCode))")
                                .tag(Optional(languageCode))
                        }
                        ForEach(PhraseLanguage.availableCodes, id: \.self) { code in
                            Text(PhraseLanguage.title(for: code))
                                .tag(Optional(code))
                                .accessibilityIdentifier("phrase-language-\(code)")
                        }
                    }
                    .accessibilityIdentifier("phrase-spoken-language")
                    Text("Choose a language available on this device. This phrase uses it when spoken or shared as audio; the rest of the board keeps its current voice.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("When tapped") {
                    Picker("Action for this phrase", selection: $tapActionOverride) {
                        Text("Use profile setting").tag(PhraseTapAction?.none)
                        Text("Speak").tag(Optional(PhraseTapAction.speak))
                        Text("Add to text")
                            .tag(Optional(PhraseTapAction.insertTyped))
                            .accessibilityIdentifier("phrase-action-insert")
                    }
                    .accessibilityIdentifier("phrase-tap-action-override")
                    Text("This choice applies in Quick phrases and on the picture phrase board. Fill-in phrases still open their form first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Folder link") {
                    Picker("Open folder instead", selection: $folderLink) {
                        Text("No folder link").tag(PhraseFolderLink?.none)
                        if let folderLink, !store.phraseFolderLinkOptions.contains(folderLink) {
                            Text("Unavailable: \(folderLink.title)").tag(Optional(folderLink))
                        }
                        ForEach(store.phraseFolderLinkOptions, id: \.self) { link in
                            Text(link.title).tag(Optional(link))
                        }
                    }
                    .accessibilityIdentifier("phrase-folder-link")
                    Text("Tapping this phrase opens the chosen folder on the picture phrase board instead of speaking or adding text. Clear the link to use its normal tap action.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Build words in a typed message") {
                    Picker("Join with other phrases", selection: $joinBehavior) {
                        ForEach(PhraseJoinBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    .accessibilityIdentifier("phrase-join-behavior")
                    Text("A prefix joins the next phrase without a space. A suffix joins the previous phrase without a space. This applies when the tap action is Add to text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Picture cue") {
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 104, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Phrase picture")
                    }
                    if arasaacPictogramID != nil {
                        Text(ARASAACPictogramService.attribution)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Photos", systemImage: "photo")
                            }
                            .accessibilityIdentifier("phrase-picture-photos")
                            Button("Files", systemImage: "folder") { showingImageImporter = true }
                                .accessibilityIdentifier("phrase-picture-files")
                            Button("ARASAAC", systemImage: "magnifyingglass") {
                                showingPictogramSearch = true
                            }
                            .accessibilityIdentifier("phrase-picture-arasaac")
                            CameraPhotoButton {
                                imageData = $0
                                arasaacPictogramID = nil
                            }
                            if imageData != nil {
                                Button("Remove picture", systemImage: "xmark.circle") {
                                    imageData = nil
                                    arasaacPictogramID = nil
                                }
                                    .accessibilityIdentifier("phrase-picture-remove")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .scrollIndicators(.hidden)
                    Text("This picture appears beside the phrase. Speech still uses the phrase text or its saved recording.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Phrase color") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Button("Default") { colorHex = nil }
                                .accessibilityIdentifier("phrase-color-default")
                            ForEach(0..<Self.colorChoices.count, id: \.self) { index in
                                let choice = Self.colorChoices[index]
                                Button { colorHex = choice.hex } label: {
                                    Text(choice.name)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(ButtonColorAppearance.color(ButtonColorValue(text: choice.hex)!),
                                                    in: Capsule())
                                        .overlay(Capsule().strokeBorder(colorHex == choice.hex ? Color.primary : .clear,
                                                                       lineWidth: 2))
                                }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("phrase-color-\(choice.name.lowercased())")
                                    .accessibilityValue(colorHex == choice.hex ? "Selected" : "")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .scrollIndicators(.hidden)
                    ColorPicker("Custom color", selection: Binding(
                        get: { colorHex.flatMap { ButtonColorValue(text: $0) }
                            .map(ButtonColorAppearance.color) ?? .white },
                        set: { colorHex = ButtonColorAppearance.hex(from: $0) }
                    ))
                    Text(colorHex == nil ? "Default list color" : "Color selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if phrase.audioData != nil && editedText.trimmingCharacters(in: .whitespacesAndNewlines) != phrase.text {
                    Section {
                        Text("Changing this text removes its saved recording. You can record it again afterward.")
                            .foregroundStyle(.secondary)
                    }
                }
                if !errorText.isEmpty {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Edit phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if store.updatePhraseDetails(phrase, text: editedText, shortcut: shortcut,
                                                     label: editedLabel) {
                            if store.setPhraseAppearance(phrase, imageData: imageData, colorHex: colorHex,
                                                         arasaacPictogramID: arasaacPictogramID),
                               store.updatePhraseLanguage(phrase, languageCode: languageCode),
                               store.updatePhraseTapAction(phrase, override: tapActionOverride),
                               store.updatePhraseJoinBehavior(phrase, behavior: joinBehavior),
                               store.updatePhraseFolderLink(phrase, to: folderLink) {
                                dismiss()
                            } else { errorText = "Could not save this phrase. Choose a current folder and a readable picture or color." }
                        } else { errorText = "Use a unique phrase, a card label up to 40 characters, and a unique shortcut of 2 to 12 letters or numbers." }
                    }
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showingPictogramSearch) {
            ARASAACPictogramSearchView(initialQuery: editedText,
                                       language: store.settings.communicationLanguage) { data, id in
                imageData = data
                arasaacPictogramID = id
            }
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { useImageData(try Data(contentsOf: url)) }
                catch { photoError = error.localizedDescription }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { photoError = error.localizedDescription }
            }
        }
        .onChange(of: selectedPhoto) { _, selected in
            guard let selected else { return }
            Task {
                do {
                    guard let data = try await selected.loadTransferable(type: Data.self) else {
                        throw ReadAloudDocumentError.unreadableFile
                    }
                    useImageData(data)
                } catch { photoError = error.localizedDescription }
                selectedPhoto = nil
            }
        }
        .alert("Could not use picture", isPresented: Binding(
            get: { photoError != nil }, set: { if !$0 { photoError = nil } }
        )) { Button("OK") { photoError = nil } } message: { Text(photoError ?? "") }
        .onChange(of: store.activeProfileID) { _, _ in dismiss() }
    }

    private static let colorChoices: [(name: String, hex: String)] = [
        ("Lavender", "#E7E2FF"), ("Sky", "#DDEBFF"), ("Mint", "#DDF5E5"),
        ("Peach", "#FFE7D3"), ("Rose", "#FFE1EA"), ("Yellow", "#FFF1C8")
    ]

    private func useImageData(_ data: Data) {
        if let prepared = PhotoProcessing.preparedData(from: data) {
            imageData = prepared
            arasaacPictogramID = nil
        }
        else { photoError = "Choose a readable image file." }
    }
}
