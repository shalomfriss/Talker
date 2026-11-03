import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PhraseFileDelivery {
    case save
    case share
}

private enum PhraseFileImportKind {
    case phraseCollection
    case messageBank
}

struct PhrasesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @ObservedObject private var voiceCatalog = SpeechVoiceCatalog.shared
    let openKeyboard: () -> Void
    @State private var newPhrase = ""
    @State private var newLabel = ""
    @State private var newFolder = ""
    @State private var newShortcut = ""
    @State private var newLanguageCode: String?
    @State private var newTapActionOverride: PhraseTapAction?
    @State private var newJoinBehavior: PhraseJoinBehavior = .normal
    @State private var newFolderLink: PhraseFolderLink?
    @State private var openedFolderLink: PhraseFolderLink?
    @State private var addError = ""
    @State private var searchText = ""
    @State private var recordingPhrase: SavedPhrase?
    @State private var fillingPhrase: SavedPhrase?
    @State private var editingPhrase: SavedPhrase?
    @State private var movingPhrase: SavedPhrase?
    @State private var showingFolderRename = false
    @State private var folderToRename = ""
    @State private var renamedFolder = ""
    @State private var showingSingleButton = false
    @State private var targetFolder = ""
    @State private var showingFileImporter = false
    @State private var fileImportKind: PhraseFileImportKind = .phraseCollection
    @State private var showingPhraseFileScope = false
    @State private var phraseFileDelivery: PhraseFileDelivery = .save
    @State private var showingPhraseFileExporter = false
    @State private var phraseFileDocument: BackupDocument?
    @State private var phraseFileSharePayload: AudioSharePayload?
    @State private var phraseFileShareURL: URL?
    @State private var phraseFileName = "open-voice-phrases"
    @State private var pendingPhraseFile: PendingPhraseFileImport?
    @State private var phraseFileStatus: String?
    @State private var phraseFileError: String?
    @State private var isReadingPhraseFile = false
    @State private var showingNotes = false
    @State private var showingReadAloud = false
    @State private var showingBedside = false
    @State private var isImportingBank = false
    @State private var bankImportStatus: String?
    @State private var audioSharePayload: AudioSharePayload?
    @State private var audioShareError = ""
    @State private var showingAudioShareError = false
    @State private var sharingAudioPhraseID: UUID?

    private var matchingPhrases: [SavedPhrase] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.phrases }
        return store.phrases.filter {
            $0.text.localizedStandardContains(query)
                || ($0.label?.localizedStandardContains(query) ?? false)
                || ($0.folder?.localizedStandardContains(query) ?? false)
                || ($0.shortcut?.localizedStandardContains(query) ?? false)
        }
    }

    private var folderNames: [String] {
        Array(Set(matchingPhrases.compactMap(\.folder)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var allFolderNames: [String] {
        Array(Set(store.phrases.compactMap(\.folder)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var matchingRecentPhrases: [SavedPhrase] {
        let matchingIDs = Set(matchingPhrases.map(\.id))
        return store.recentPhrases.filter { matchingIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Saved phrase taps") {
                    Picker("When tapped", selection: $store.settings.phraseTapAction) {
                        Text("Speak").tag(PhraseTapAction.speak)
                        Text("Add to text").tag(PhraseTapAction.insertTyped)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("phrase-tap-action")
                    Text(store.settings.phraseTapAction == .speak
                         ? "Tap a phrase to speak it. A phrase with its own tap action uses that choice. Templates open a form first."
                         : "Tap a phrase to add it to the typed draft and open Keyboard. A phrase with its own tap action uses that choice. Fill a template, then choose Insert into typed message.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Touch and hold a phrase to change its order within its folder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        PhraseCardBoardView(openKeyboard: openKeyboard)
                    } label: {
                        Label("Picture phrase board", systemImage: "rectangle.grid.2x2")
                    }
                    .accessibilityIdentifier("phrases-card-board")
                }
                Section("Recent phrases") {
                    Toggle("Keep recently used phrases", isOn: $store.settings.recentPhrasesEnabled)
                        .accessibilityIdentifier("recent-phrases-setting")
                    if store.settings.recentPhrasesEnabled {
                        if matchingRecentPhrases.isEmpty {
                            Text(searchText.isEmpty
                                 ? "Phrases you speak or add to text will appear here."
                                 : "No recent phrases match this search.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(matchingRecentPhrases) { phrase in phraseRow(phrase, recent: true) }
                        }
                        Button("Clear recent phrases", systemImage: "trash") {
                            store.clearRecentPhrases()
                        }
                        .disabled(store.settings.recentPhraseIDs.isEmpty)
                        .accessibilityIdentifier("clear-recent-phrases")
                    }
                }
                Section("Express yourself") {
                    Button("Notes", systemImage: "note.text") { showingNotes = true }
                        .accessibilityIdentifier("phrases-open-notes")
                    Button("Read aloud", systemImage: "doc.text.magnifyingglass") {
                        showingReadAloud = true
                    }
                    .accessibilityIdentifier("phrases-open-read-aloud")
                    Button("Open one button mode", systemImage: "speaker.wave.3.fill") {
                        showingSingleButton = true
                    }
                    .accessibilityIdentifier("single-button-open")
                    Button("Bedside communication", systemImage: "bed.double.fill") {
                        showingBedside = true
                    }
                    .accessibilityIdentifier("phrases-open-bedside")
                    NavigationLink {
                        SingleButtonSetupView()
                    } label: {
                        Label("One button setup", systemImage: "speaker.wave.3.fill")
                    }
                    .accessibilityIdentifier("single-button-setup-link")
                    NavigationLink {
                        JokesView()
                    } label: {
                        Label("Jokes", systemImage: "theatermasks")
                    }
                    .accessibilityIdentifier("jokes-link")
                    NavigationLink {
                        SpeechCueBoardView()
                    } label: {
                        Label("Speech cues", systemImage: "textformat.abc")
                    }
                    .accessibilityIdentifier("speech-cue-link")
                    NavigationLink {
                        DrawingBoardView()
                    } label: {
                        Label("Drawing board", systemImage: "scribble.variable")
                    }
                    NavigationLink {
                        FeelingCheckInView()
                    } label: {
                        Label("How I feel", systemImage: "face.smiling")
                    }
                    .accessibilityIdentifier("feeling-check-in-link")
                    NavigationLink {
                        PainCheckInView()
                    } label: {
                        Label("Pain check-in", systemImage: "cross.case")
                    }
                    .accessibilityIdentifier("pain-check-in-link")
                    if store.settings.saveHistory {
                        NavigationLink {
                            HistoryView()
                        } label: {
                            Label("Recent messages", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
                if matchingPhrases.contains(where: { $0.folder == nil }) {
                    Section("Quick communication") {
                        ForEach(matchingPhrases.filter { $0.folder == nil }) { phrase in
                            phraseRow(phrase)
                        }
                    }
                }
                ForEach(folderNames, id: \.self) { folder in
                    Section {
                        ForEach(matchingPhrases.filter { $0.folder == folder }) { phrase in
                            phraseRow(phrase)
                        }
                    } header: {
                        HStack {
                            Text(folder)
                            Spacer()
                            Button("Rename", systemImage: "pencil") {
                                folderToRename = folder
                                renamedFolder = folder
                                showingFolderRename = true
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Rename folder \(folder)")
                        }
                    }
                }
                if matchingPhrases.isEmpty {
                    Section { Text("No matching phrases").foregroundStyle(.secondary) }
                }
                Section("Phrase files") {
                    Button("Export phrase file", systemImage: "square.and.arrow.up") {
                        phraseFileDelivery = .save
                        showingPhraseFileScope = true
                    }
                    .disabled(store.phrases.isEmpty)
                    .accessibilityIdentifier("export-phrase-file")
                    Button("Share phrase file", systemImage: "square.and.arrow.up.on.square") {
                        phraseFileDelivery = .share
                        showingPhraseFileScope = true
                    }
                    .disabled(store.phrases.isEmpty)
                    .accessibilityIdentifier("share-phrase-file")
                    Button("Import phrase file", systemImage: "square.and.arrow.down") {
                        fileImportKind = .phraseCollection
                        showingFileImporter = true
                    }
                    .disabled(isReadingPhraseFile)
                    .accessibilityIdentifier("import-phrase-file")
                    Text("Share all phrases or one folder as a JSON file. Import previews new and matching phrases before changing this profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if isReadingPhraseFile { ProgressView("Reading phrase file") }
                    if let phraseFileStatus { Text(phraseFileStatus).foregroundStyle(.secondary) }
                }
                Section("Message bank") {
                    Button("Import recorded messages", systemImage: "square.and.arrow.down") {
                        fileImportKind = .messageBank
                        showingFileImporter = true
                    }
                    .disabled(isImportingBank)
                    .accessibilityIdentifier("message-bank-import")
                    Text("Choose audio files or a ZIP of recordings. File names become editable phrase text. When a message matches that text, Speak plays the recording. Existing phrases are kept.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if isImportingBank { ProgressView("Importing recordings") }
                    if let bankImportStatus { Text(bankImportStatus).foregroundStyle(.secondary) }
                }
                Section("Add your own") {
                    TextField("A phrase you use often", text: $newPhrase, axis: .vertical)
                    TextField("Short card label (optional)", text: $newLabel)
                        .accessibilityIdentifier("new-phrase-card-label")
                    Text("Use {word} to ask for a detail, such as: I would like {drink}.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Folder (optional)", text: $newFolder)
                    TextField("Typing shortcut (optional)", text: $newShortcut)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Spoken language", selection: $newLanguageCode) {
                        Text("Use current voice").tag(String?.none)
                        ForEach(PhraseLanguage.codes(from: voiceCatalog.voices), id: \.self) { code in
                            Text(PhraseLanguage.title(for: code))
                                .tag(Optional(code))
                                .accessibilityIdentifier("new-phrase-language-\(code)")
                        }
                    }
                    .accessibilityIdentifier("new-phrase-language")
                    Picker("When tapped", selection: $newTapActionOverride) {
                        Text("Use profile setting").tag(PhraseTapAction?.none)
                        Text("Speak").tag(Optional(PhraseTapAction.speak))
                        Text("Add to text")
                            .tag(Optional(PhraseTapAction.insertTyped))
                            .accessibilityIdentifier("new-phrase-action-insert")
                    }
                    .accessibilityIdentifier("new-phrase-tap-action")
                    Picker("Open folder instead", selection: $newFolderLink) {
                        Text("No folder link").tag(PhraseFolderLink?.none)
                        ForEach(store.phraseFolderLinkOptions, id: \.self) { link in
                            Text(link.title).tag(Optional(link))
                        }
                    }
                    .accessibilityIdentifier("new-phrase-folder-link")
                    Text("A folder link opens that phrase folder on the picture board when tapped.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Join with other phrases", selection: $newJoinBehavior) {
                        ForEach(PhraseJoinBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    .accessibilityIdentifier("new-phrase-join-behavior")
                    Text("Prefix and suffix joining applies when the phrase adds to text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !addError.isEmpty { Text(addError).foregroundStyle(.red) }
                    Button("Save phrase", systemImage: "plus") {
                        if store.addPhrase(newPhrase, folder: newFolder, shortcut: newShortcut,
                                           label: newLabel, languageCode: newLanguageCode,
                                           tapActionOverride: newTapActionOverride,
                                           joinBehavior: newJoinBehavior,
                                           folderLink: newFolderLink) {
                            newPhrase = ""
                            newLabel = ""
                            newShortcut = ""
                            newJoinBehavior = .normal
                            newFolderLink = nil
                            addError = ""
                        } else {
                            addError = "Use a unique phrase, a card label up to 40 characters, and a unique shortcut of 2 to 12 letters or numbers."
                        }
                    }
                    .disabled(newPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("From your message") {
                    Button("Save current message", systemImage: "square.and.arrow.down") {
                        store.addPhrase(store.composedMessage, folder: newFolder)
                    }
                    .disabled(store.composedMessage.isEmpty)
                }
            }
            .navigationTitle("Quick phrases")
            .navigationDestination(item: $openedFolderLink) { link in
                PhraseCardBoardView(openKeyboard: openKeyboard, initialFolderLink: link)
            }
            .searchable(text: $searchText, prompt: "Find a phrase")
            .confirmationDialog("Which phrases?", isPresented: $showingPhraseFileScope) {
                Button("All phrases") {
                    exportPhraseFile(store.phrases, named: "All phrases", delivery: phraseFileDelivery)
                }
                if store.phrases.contains(where: { $0.folder == nil }) {
                    Button("Quick communication") {
                        exportPhraseFile(store.phrases.filter { $0.folder == nil },
                                         named: "Quick communication", delivery: phraseFileDelivery)
                    }
                }
                ForEach(allFolderNames, id: \.self) { folder in
                    Button(folder) {
                        exportPhraseFile(store.phrases.filter { $0.folder == folder },
                                         named: folder, delivery: phraseFileDelivery)
                    }
                }
            } message: {
                Text("Choose all saved phrases or one folder.")
            }
            .fileExporter(isPresented: $showingPhraseFileExporter, document: phraseFileDocument,
                          contentType: .json, defaultFilename: phraseFileName) { result in
                showingPhraseFileExporter = false
                phraseFileDocument = nil
                if case .failure(let error) = result { phraseFileError = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: fileImportKind == .phraseCollection ? [.json] : [.audio, .zip],
                          allowsMultipleSelection: fileImportKind == .messageBank) { result in
                switch fileImportKind {
                case .phraseCollection: handlePhraseFileImport(result)
                case .messageBank: handleMessageBankImport(result)
                }
            }
            .sheet(item: $recordingPhrase) { PhraseRecordingEditorView(phrase: $0) }
            .sheet(isPresented: $showingNotes) {
                CommunicationNotesView(onUseInDraft: openKeyboard)
            }
            .sheet(isPresented: $showingReadAloud) { ReadAloudView() }
            .fullScreenCover(isPresented: $showingSingleButton) { SingleButtonView() }
            .fullScreenCover(isPresented: $showingBedside) { BedsideView() }
            .sheet(item: $fillingPhrase) { phrase in
                PhraseTemplateFillView(phrase: phrase) { completed in
                    if store.appendTypedPhrase(completed, joinBehavior: phrase.joinBehavior) {
                        store.recordRecentPhrase(phrase)
                        openKeyboard()
                    }
                }
            }
            .sheet(item: $editingPhrase) { PhraseTextEditorView(phrase: $0) }
            .sheet(item: $pendingPhraseFile) { pending in
                PhraseFileImportView(pending: pending) { result in
                    var summary = "Added \(result.added), updated \(result.updated), skipped \(result.skipped) phrases."
                    if result.clearedShortcuts > 0 {
                        summary += " Cleared \(result.clearedShortcuts) conflicting shortcuts."
                    }
                    if result.omittedPictures + result.omittedRecordings > 0 {
                        summary += " Omitted \(result.omittedPictures) unreadable pictures and \(result.omittedRecordings) unreadable recordings."
                    }
                    phraseFileStatus = summary
                }
            }
            .sheet(item: $audioSharePayload) { AudioShareSheet(url: $0.url) }
            .sheet(item: $phraseFileSharePayload, onDismiss: {
                if let url = phraseFileShareURL { try? FileManager.default.removeItem(at: url) }
                phraseFileShareURL = nil
            }) { AudioShareSheet(url: $0.url) }
            .alert("Phrase file error", isPresented: Binding(
                get: { phraseFileError != nil }, set: { if !$0 { phraseFileError = nil } }
            )) { Button("OK") { phraseFileError = nil } }
                message: { Text(phraseFileError ?? "") }
            .alert("Couldn't share audio", isPresented: $showingAudioShareError) {
                Button("OK", role: .cancel) {}
            } message: { Text(audioShareError) }
            .sheet(item: $movingPhrase) { phrase in
                NavigationStack {
                    Form {
                        Section("Phrase") { Text(phrase.text) }
                        Section("Folder") {
                            TextField("Folder name", text: $targetFolder)
                                .textInputAutocapitalization(.words)
                            Text("Leave blank to show this phrase in Quick communication.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Move phrase")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { movingPhrase = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Move") {
                                store.movePhrase(phrase, to: targetFolder)
                                movingPhrase = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingFolderRename) {
                NavigationStack {
                    Form {
                        TextField("Folder name", text: $renamedFolder)
                            .textInputAutocapitalization(.words)
                    }
                    .navigationTitle("Rename folder")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingFolderRename = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if store.renamePhraseFolder(folderToRename, to: renamedFolder) {
                                    showingFolderRename = false
                                }
                            }
                            .disabled(renamedFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onChange(of: store.activeProfileID) { _, _ in
                newPhrase = ""
                newLabel = ""
                newFolder = ""
                newShortcut = ""
                newLanguageCode = nil
                newTapActionOverride = nil
                newJoinBehavior = .normal
                newFolderLink = nil
                openedFolderLink = nil
                addError = ""
                searchText = ""
                recordingPhrase = nil
                fillingPhrase = nil
                editingPhrase = nil
                movingPhrase = nil
                showingFolderRename = false
                bankImportStatus = nil
                showingFileImporter = false
                showingPhraseFileScope = false
                showingPhraseFileExporter = false
                phraseFileDocument = nil
                phraseFileSharePayload = nil
                pendingPhraseFile = nil
                phraseFileStatus = nil
                phraseFileError = nil
                isReadingPhraseFile = false
                audioSharePayload = nil
                showingAudioShareError = false
            }
        }
        .onAppear { voiceCatalog.refresh() }
    }

    private func phraseRow(_ phrase: SavedPhrase, recent: Bool = false) -> some View {
        let isTemplate = !PhraseTemplate.fields(in: phrase.text).isEmpty
        let tapAction = phrase.effectiveTapAction(fallback: store.settings.phraseTapAction)
        let appearance = store.settings.highContrast ? nil : phrase.colorHex.flatMap(ButtonColorValue.init(text:))
        return HStack(spacing: 12) {
            Button {
                if let link = phrase.folderLink, store.phraseFolderLinkOptions.contains(link) {
                    openedFolderLink = link
                } else if isTemplate { fillingPhrase = phrase }
                else if tapAction == .speak { store.speakPhrase(phrase) }
                else if store.appendTypedPhrase(phrase) { openKeyboard() }
            } label: {
                HStack(spacing: 10) {
                    if let data = phrase.imageData {
                        AsyncThumbnailImage(data: data) {
                            Image(systemName: phrase.folderLink != nil ? "folder.fill" : isTemplate ? "text.badge.plus" :
                                  (phrase.audioData == nil ? "speaker.wave.2.fill" : "waveform"))
                        }
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: phrase.folderLink != nil ? "folder.fill" : isTemplate ? "text.badge.plus" :
                              (phrase.audioData == nil ? "speaker.wave.2.fill" : "waveform"))
                            .frame(width: 50, height: 50)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phrase.displayLabel)
                        if let link = phrase.folderLink {
                            Label("Opens \(link.title)", systemImage: "arrow.turn.down.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if phrase.label != nil {
                            Text(phrase.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let languageCode = phrase.languageCode {
                            Label(languageCode, systemImage: "globe")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if phrase.arasaacPictogramID != nil {
                            Text(ARASAACPictogramService.attribution)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let override = phrase.tapActionOverride {
                            Label(override.title, systemImage: override == .speak
                                  ? "speaker.wave.2" : "keyboard")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if phrase.joinBehavior != .normal {
                            Text(phrase.joinBehavior == .prefix ? "Prefix" : "Suffix")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(appearance?.prefersDarkText == false ? Color.white : Color.primary)
                    .background(appearance.map(ButtonColorAppearance.color) ?? .clear,
                                in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(phrase.accessibleLabel)
            .accessibilityIdentifier("\(recent ? "recent" : "saved")-phrase-\(phrase.id)")
            .accessibilityHint(phrase.folderLink.map { "Open \($0.title) folder" } ?? (isTemplate ? "Fill in this phrase" :
                               (tapAction == .insertTyped
                                ? "Add to the typed draft and open Keyboard"
                                : (phrase.audioData == nil ? "Speak with the system voice" : "Play the recorded voice"))))
            if let shortcut = phrase.shortcut {
                Text(shortcut)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if !isTemplate && phrase.folderLink == nil {
                Button {
                    recordingPhrase = phrase
                } label: {
                    Image(systemName: "mic")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Record voice for \(phrase.text)")
                Menu {
                    ShareLink(item: phrase.text) {
                        Label("Share text", systemImage: "doc.on.doc")
                    }
                    Button("Share audio", systemImage: "waveform") {
                        prepareAudioShare(phrase)
                    }
                    .disabled(sharingAudioPhraseID != nil)
                } label: {
                    Group {
                        if sharingAudioPhraseID == phrase.id { ProgressView() }
                        else { Image(systemName: "square.and.arrow.up") }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share \(phrase.text)")
            }
        }
        .swipeActions(edge: .leading) {
            Button("Move to folder", systemImage: "folder") { beginMoving(phrase) }
            Button("Edit phrase", systemImage: "pencil") { editingPhrase = phrase }
        }
        .swipeActions {
            Button("Delete", role: .destructive) { store.deletePhrase(phrase) }
        }
        .contextMenu {
            Button("Edit phrase", systemImage: "pencil") { editingPhrase = phrase }
            Button("Move to folder", systemImage: "folder") { beginMoving(phrase) }
            Button("Move earlier", systemImage: "arrow.up") { store.movePhrase(phrase, by: -1) }
                .disabled(!store.canMovePhrase(phrase, by: -1))
            Button("Move later", systemImage: "arrow.down") { store.movePhrase(phrase, by: 1) }
                .disabled(!store.canMovePhrase(phrase, by: 1))
        }
    }

    private func beginMoving(_ phrase: SavedPhrase) {
        targetFolder = phrase.folder ?? ""
        movingPhrase = phrase
    }

    private func handlePhraseFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let profileID = store.activeProfileID
            isReadingPhraseFile = true
            phraseFileStatus = nil
            Task {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        return try Data(contentsOf: url)
                    }.value
                    guard store.activeProfileID == profileID else {
                        isReadingPhraseFile = false
                        return
                    }
                    pendingPhraseFile = PendingPhraseFileImport(
                        profileID: profileID,
                        collection: try PhraseCollectionTransfer.importData(data))
                } catch {
                    if store.activeProfileID == profileID {
                        phraseFileError = error.localizedDescription
                    }
                }
                isReadingPhraseFile = false
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                phraseFileError = error.localizedDescription
            }
        }
    }

    private func handleMessageBankImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            let profileID = store.activeProfileID
            isImportingBank = true
            bankImportStatus = nil
            Task {
                let batch = await Task.detached(priority: .userInitiated) {
                    MessageBankImporter.read(urls)
                }.value
                guard store.activeProfileID == profileID else {
                    isImportingBank = false
                    return
                }
                let count = store.importBankedMessages(batch)
                bankImportStatus = "Imported \(count.imported) recordings; skipped \(count.skipped)."
                isImportingBank = false
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                bankImportStatus = error.localizedDescription
            }
        }
    }

    private func exportPhraseFile(_ phrases: [SavedPhrase], named name: String,
                                  delivery: PhraseFileDelivery) {
        do {
            let data = try PhraseCollectionTransfer.exportData(phrases, named: name)
            switch delivery {
            case .save:
                phraseFileDocument = BackupDocument(data: data)
                phraseFileName = "open-voice-phrases"
                showingPhraseFileExporter = true
            case .share:
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("open-voice-phrases-\(UUID().uuidString).json")
                try data.write(to: url, options: .atomic)
                phraseFileShareURL = url
                phraseFileSharePayload = AudioSharePayload(url: url)
            }
        } catch {
            phraseFileError = error.localizedDescription
        }
    }

    private func prepareAudioShare(_ phrase: SavedPhrase) {
        guard sharingAudioPhraseID == nil else { return }
        sharingAudioPhraseID = phrase.id
        let profileID = store.activeProfileID
        Task {
            defer { sharingAudioPhraseID = nil }
            do {
                let url = try await store.exportPhraseAudio(phrase)
                guard store.activeProfileID == profileID else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                audioSharePayload = AudioSharePayload(url: url)
            } catch {
                guard store.activeProfileID == profileID else { return }
                audioShareError = error.localizedDescription
                showingAudioShareError = true
            }
        }
    }
}
