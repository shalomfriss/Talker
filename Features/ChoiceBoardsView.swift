import SwiftUI
import UniformTypeIdentifiers

private enum ChoiceBoardFolderFilter: Hashable {
    case all
    case unfiled
    case folder(String)
}

private enum QuickChoiceField: Hashable {
    case question
    case choices
}

struct ChoiceBoardsView: View {
    @EnvironmentObject private var store: CommunicationStore
    private var editingBlocked: Bool { store.settings.choiceBoardEditingLocked || store.isBoardOnlyModeActive }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeBoard: ChoiceBoard?
    @State private var editingBoard: ChoiceBoard?
    @State private var showingNewBoard = false
    @State private var showingBoardImporter = false
    @State private var showingBoardExporter = false
    @State private var boardExportDocument: BackupDocument?
    @State private var boardExportName = "choice-board.json"
    @State private var transferError: String?
    @State private var folderFilter: ChoiceBoardFolderFilter = .all
    @State private var quickQuestion = ""
    @State private var quickChoices = ""
    @State private var quickFeedback: String?
    @StateObject private var choiceRecorder = AudioMessageRecorder()
    @State private var choiceTranscriber = SpokenChoiceTranscriber()
    @State private var spokenChoice = ""
    @State private var speechFeedback: String?
    @State private var isPreparingRecording = false
    @State private var isTranscribing = false
    @State private var recordingAttemptID = UUID()
    @FocusState private var isReviewFocused: Bool
    @FocusState private var focusedQuickField: QuickChoiceField?

    private var quickDraft: QuickChoiceDraft {
        QuickChoiceDraft(question: quickQuestion, choices: quickChoices)
    }

    private var visibleChoiceBoards: [ChoiceBoard] {
        switch folderFilter {
        case .all: store.choiceBoards
        case .unfiled: store.choiceBoards.filter { $0.folder == nil }
        case .folder(let name): store.choiceBoards.filter {
            $0.folder?.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Offer choices without limiting the conversation. The full Speak board is always one tap away.")
                        .foregroundStyle(.secondary)
                }
                Section("Quick choices") {
                    TextField("Question (optional)", text: $quickQuestion)
                        .focused($focusedQuickField, equals: .question)
                        .accessibilityIdentifier("quick-choice-question")
                        .onChange(of: quickQuestion) { _, _ in quickFeedback = nil }
                    TextField("Water, juice, milk", text: $quickChoices, axis: .vertical)
                        .focused($focusedQuickField, equals: .choices)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("quick-choice-options")
                        .onChange(of: quickChoices) { _, _ in quickFeedback = nil }
                    Text("Type 2 to 8 different choices, separated by commas or new lines. Choices already in Speak use their existing pictures and voices.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let quickFeedback {
                        Text(quickFeedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("quick-choice-feedback")
                    }
                    HStack {
                        Button("Show choices", systemImage: "rectangle.expand.vertical") {
                            presentQuickChoices()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!quickDraft.isValid || choiceRecorder.isRecording || isPreparingRecording || isTranscribing)
                        .accessibilityIdentifier("show-quick-choices")
                        Button("Save for later", systemImage: "bookmark") {
                            guard !editingBlocked else { return }
                            guard let board = quickDraft.board(using: store.items) else { return }
                            quickFeedback = store.saveChoiceBoard(board)
                                ? "Saved to My choice boards."
                                : "That title is already used. Give this board a different question."
                            focusedQuickField = nil
                        }
                        .buttonStyle(.bordered)
                        .disabled(!quickDraft.isValid || editingBlocked ||
                                  choiceRecorder.isRecording || isPreparingRecording || isTranscribing)
                    }
                }
                Section("Speak a choice") {
                    Text("Record one option, then review the words before adding it. Recognition stays on this device; the recording is deleted after transcription.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(choiceRecorder.isRecording ? "Stop and transcribe" : "Record one choice",
                           systemImage: choiceRecorder.isRecording ? "stop.circle.fill" : "mic.fill") {
                        if choiceRecorder.isRecording { stopAndTranscribe() }
                        else { startRecording() }
                    }
                    .disabled(isPreparingRecording || isTranscribing ||
                              (!choiceRecorder.isRecording && quickDraft.labels.count >= 8))
                    .accessibilityIdentifier("spoken-choice-record-toggle")
                    if choiceRecorder.isRecording {
                        Label("Recording one choice", systemImage: "waveform")
                            .foregroundStyle(.red)
                    }
                    if isPreparingRecording || isTranscribing {
                        ProgressView(isTranscribing ? "Transcribing choice" : "Preparing microphone")
                    }
                    Button("Add spoken choice", systemImage: "plus.circle.fill") { addSpokenChoice() }
                        .disabled(SpokenChoiceText.adding(spokenChoice, to: quickChoices) == nil ||
                                  choiceRecorder.isRecording || isPreparingRecording || isTranscribing)
                        .accessibilityIdentifier("spoken-choice-add")
                    Button("Show these choices", systemImage: "rectangle.expand.vertical") {
                        presentQuickChoices()
                    }
                    .disabled(!quickDraft.isValid || choiceRecorder.isRecording || isPreparingRecording || isTranscribing)
                    .accessibilityIdentifier("show-spoken-choices")
                    Text("\(quickDraft.labels.count) of 8 choices ready")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("spoken-choice-count")
                    TextField("Review spoken choice", text: $spokenChoice)
                        .focused($isReviewFocused)
                        .submitLabel(.done)
                        .onSubmit(addSpokenChoice)
                        .accessibilityIdentifier("spoken-choice-review")
                        .onChange(of: spokenChoice) { _, _ in speechFeedback = nil }
                    if let feedback = speechFeedback ?? choiceRecorder.errorMessage {
                        Text(feedback)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("spoken-choice-feedback")
                    }
                }
                Section("My choice boards") {
                    if !store.choiceBoardFolders.isEmpty {
                        Picker("Show boards", selection: $folderFilter) {
                            Text("All boards").tag(ChoiceBoardFolderFilter.all)
                            Text("Unfiled").tag(ChoiceBoardFolderFilter.unfiled)
                            ForEach(store.choiceBoardFolders, id: \.self) { folder in
                                Text(folder).tag(ChoiceBoardFolderFilter.folder(folder))
                            }
                        }
                        .accessibilityIdentifier("choice-board-folder-filter")
                        .onChange(of: folderFilter) { _, _ in focusedQuickField = nil }
                    }
                    ForEach(visibleChoiceBoards) { board in
                        HStack(spacing: 12) {
                            Button {
                                focusedQuickField = nil
                                activeBoard = board
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(board.title).font(.headline)
                                    Text(board.folder.map { "\($0) · \(board.options.count) choices" }
                                         ?? "\(board.options.count) choices")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(board.title)")
                            Menu {
                                Button("Export board file", systemImage: "square.and.arrow.up") {
                                    exportChoiceBoard(board)
                                }
                                if !editingBlocked {
                                    Button("Edit board", systemImage: "pencil") {
                                        focusedQuickField = nil
                                        editingBoard = board
                                    }
                                    Button("Move up", systemImage: "arrow.up") { moveBoard(board, by: -1) }
                                        .disabled(visibleChoiceBoards.first?.id == board.id)
                                    Button("Move down", systemImage: "arrow.down") { moveBoard(board, by: 1) }
                                        .disabled(visibleChoiceBoards.last?.id == board.id)
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        store.deleteChoiceBoard(id: board.id)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("Options for \(board.title)")
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        _ = store.moveChoiceBoards(ids: visibleChoiceBoards.map(\.id),
                                                   fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                    Button("Create a choice board", systemImage: "plus") { showingNewBoard = true }
                        .disabled(editingBlocked)
                    Button("Import choice board file", systemImage: "square.and.arrow.down") {
                        showingBoardImporter = true
                    }
                    .disabled(editingBlocked)
                    .accessibilityIdentifier("import-choice-board")
                }
            }
            .navigationTitle("Choice boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                if editingBlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Image(systemName: "lock.fill")
                            .accessibilityLabel("Choice-board editing locked for this profile")
                            .accessibilityIdentifier("choice-board-locked")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New board", systemImage: "plus") { showingNewBoard = true }
                        .disabled(editingBlocked)
                }
                if !editingBlocked && visibleChoiceBoards.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
            .sheet(item: $activeBoard) { board in
                ChoiceBoardSessionView(board: board) {
                    activeBoard = nil
                    dismiss()
                }
            }
            .sheet(item: $editingBoard) { ChoiceBoardEditorView(board: $0) }
            .sheet(isPresented: $showingNewBoard) { ChoiceBoardEditorView(board: nil) }
            .fileExporter(isPresented: $showingBoardExporter, document: boardExportDocument,
                          contentType: .json, defaultFilename: boardExportName) { result in
                if case .failure(let error) = result { transferError = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingBoardImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { try? file.close() }
                    let data = try file.read(upToCount: ChoiceBoardTransfer.maxImportBytes + 1) ?? Data()
                    guard data.count <= ChoiceBoardTransfer.maxImportBytes else {
                        throw ChoiceBoardTransferError.tooLarge
                    }
                    let imported = try store.importChoiceBoard(data)
                    transferError = "Added \(imported.title) to My choice boards."
                } catch { transferError = error.localizedDescription }
            }
            .alert("Choice board file", isPresented: Binding(
                get: { transferError != nil }, set: { if !$0 { transferError = nil } }
            )) {
                Button("OK") { transferError = nil }
            } message: {
                Text(transferError ?? "")
            }
            .onDisappear { discardPendingSpeech() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { discardPendingSpeech() }
            }
            .onChange(of: editingBlocked) { _, locked in
                if locked {
                    editingBoard = nil
                    showingNewBoard = false
                }
            }
            .onChange(of: store.choiceBoardFolders) { _, folders in
                if case .folder(let name) = folderFilter,
                   !folders.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                    folderFilter = .all
                }
            }
        }
    }

    private func startRecording() {
        let attemptID = UUID()
        recordingAttemptID = attemptID
        speechFeedback = nil
        isPreparingRecording = true
        store.stopSpeaking()
        Task {
            defer { isPreparingRecording = false }
            do {
                try await choiceTranscriber.prepare(language: store.settings.communicationLanguage)
                guard recordingAttemptID == attemptID else { return }
                await choiceRecorder.start()
            } catch {
                guard recordingAttemptID == attemptID else { return }
                speechFeedback = error.localizedDescription
            }
        }
    }

    private func stopAndTranscribe() {
        guard let data = choiceRecorder.stop() else {
            speechFeedback = "The recording could not be read. Try again or type the choice."
            return
        }
        isTranscribing = true
        speechFeedback = nil
        Task {
            defer { isTranscribing = false }
            do {
                spokenChoice = try await choiceTranscriber.transcribe(data)
                speechFeedback = "Review the words, then add this choice."
            } catch is CancellationError {
                // Closing the choice screen cancels a pending transcription.
            } catch {
                speechFeedback = error.localizedDescription
            }
        }
    }

    private func addSpokenChoice() {
        guard let updated = SpokenChoiceText.adding(spokenChoice, to: quickChoices) else { return }
        quickChoices = updated
        spokenChoice = ""
        isReviewFocused = false
        speechFeedback = "Choice added. Record or type another option."
    }

    private func presentQuickChoices() {
        guard let board = quickDraft.board(using: store.items) else { return }
        isReviewFocused = false
        focusedQuickField = nil
        activeBoard = board
    }

    private func discardPendingSpeech() {
        recordingAttemptID = UUID()
        choiceRecorder.discard()
        choiceTranscriber.cancel()
        isPreparingRecording = false
        isTranscribing = false
    }

    private func exportChoiceBoard(_ board: ChoiceBoard) {
        do {
            boardExportDocument = BackupDocument(data: try ChoiceBoardTransfer.exportData(board, using: store.items))
            boardExportName = board.title.replacingOccurrences(of: "/", with: "-") + ".json"
            showingBoardExporter = true
        } catch { transferError = error.localizedDescription }
    }

    private func moveBoard(_ board: ChoiceBoard, by distance: Int) {
        let ids = visibleChoiceBoards.map(\.id)
        guard let index = ids.firstIndex(of: board.id),
              ids.indices.contains(index + distance) else { return }
        _ = store.moveChoiceBoards(ids: ids, fromOffsets: IndexSet(integer: index),
                                   toOffset: distance < 0 ? index - 1 : index + 2)
    }
}

private struct ChoiceBoardEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    private var editingBlocked: Bool { store.settings.choiceBoardEditingLocked || store.isBoardOnlyModeActive }
    @Environment(\.dismiss) private var dismiss
    let board: ChoiceBoard?
    @State private var title: String
    @State private var options: [ChoiceOption]
    @State private var folder: String
    @State private var layout: ChoiceBoardLayout
    @State private var customChoice = ""
    @State private var search = ""
    @State private var errorMessage: String?
    @State private var colorOption: ChoiceOption?

    init(board: ChoiceBoard?) {
        self.board = board
        _title = State(initialValue: board?.title ?? "")
        _options = State(initialValue: board?.options ?? [])
        _folder = State(initialValue: board?.folder ?? "")
        _layout = State(initialValue: board?.effectiveLayout ?? .grid)
    }

    private var availableWords: [CommunicationItem] {
        store.items.filter { item in
            item.destinationBoard == nil &&
            (search.isEmpty || item.label.localizedCaseInsensitiveContains(search) ||
             item.category.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Question or title") {
                    TextField("What would you like?", text: $title)
                        .accessibilityIdentifier("choice-board-title")
                }
                Section("Folder") {
                    TextField("Folder name (optional)", text: $folder)
                        .accessibilityIdentifier("choice-board-folder")
                    if !store.choiceBoardFolders.isEmpty {
                        Menu("Use an existing folder") {
                            Button("Unfiled") { folder = "" }
                            ForEach(store.choiceBoardFolders, id: \.self) { name in
                                Button(name) { folder = name }
                            }
                        }
                    }
                    Text("Use the same folder name to keep related choice boards together.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Layout") {
                    Picker("Choice layout", selection: $layout) {
                        ForEach(ChoiceBoardLayout.allCases, id: \.self) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("choice-board-layout")
                    Text(layout.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Selected choices (\(options.count) of 8)") {
                    ForEach(options) { option in
                        HStack {
                            Label(option.label, systemImage: option.imageData == nil ? "text.bubble" : "photo")
                            Spacer()
                            Button("Colors", systemImage: "paintpalette") { colorOption = option }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Colors for \(option.label)")
                        }
                    }
                    .onDelete { options.remove(atOffsets: $0) }
                    .onMove { options.move(fromOffsets: $0, toOffset: $1) }
                    if options.count < 2 {
                        Text("Add at least two choices. You can reorder or remove them here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Add your own choice") {
                    HStack {
                        TextField("Choice label", text: $customChoice)
                            .accessibilityIdentifier("custom-choice-label")
                        Button { addCustomChoice() } label: {
                            Text("Add")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(options.count >= 8 || customChoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("To use a photo or recorded voice, create a personal button in Speak and add it below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Add from my words") {
                    ForEach(availableWords) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack {
                                Text(item.symbol)
                                    .accessibilityHidden(true)
                                Text(item.label)
                                Spacer()
                                if options.contains(where: { $0.id == item.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .disabled(options.count >= 8 && !options.contains(where: { $0.id == item.id }))
                        .accessibilityLabel("\(item.label), \(options.contains(where: { $0.id == item.id }) ? "selected" : "not selected")")
                    }
                }
            }
            .searchable(text: $search, prompt: "Find a word to add")
            .sheet(item: $colorOption) { option in
                ChoiceColorEditorView(option: option) { updated in
                    if let index = options.firstIndex(where: { $0.id == updated.id }) {
                        options[index] = updated
                    }
                }
            }
            .navigationTitle(board == nil ? "New choice board" : "Edit choice board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(editingBlocked ||
                                  title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  !(2...8).contains(options.count))
                }
            }
            .alert("Could not save choice board", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Choose a different title and check each option.")
            }
        }
    }

    private func addCustomChoice() {
        let label = customChoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, options.count < 8 else { return }
        options.append(ChoiceOption(label: label))
        customChoice = ""
    }

    private func toggle(_ item: CommunicationItem) {
        if let index = options.firstIndex(where: { $0.id == item.id }) {
            options.remove(at: index)
        } else if options.count < 8 {
            options.append(ChoiceOption(item: item))
        }
    }

    private func save() {
        guard !editingBlocked else {
            errorMessage = "Choice-board editing is locked. Turn it off in Settings to make changes."
            return
        }
        let updated = ChoiceBoard(id: board?.id ?? UUID(), title: title, options: options,
                                  folder: folder, layout: layout == .grid ? nil : layout)
        if store.saveChoiceBoard(updated) {
            dismiss()
        } else {
            errorMessage = "Use a unique title and add 2 to 8 choices with distinct names."
        }
    }
}

private struct ChoiceColorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let option: ChoiceOption
    let onSave: (ChoiceOption) -> Void
    @State private var hasBackground: Bool
    @State private var hasBorder: Bool
    @State private var background: Color
    @State private var border: Color

    init(option: ChoiceOption, onSave: @escaping (ChoiceOption) -> Void) {
        self.option = option
        self.onSave = onSave
        _hasBackground = State(initialValue: option.backgroundColorHex != nil)
        _hasBorder = State(initialValue: option.borderColorHex != nil)
        _background = State(initialValue: option.backgroundColorHex
            .flatMap { ButtonColorValue(text: $0) }.map(ButtonColorAppearance.color)
            ?? Color(red: 0.99, green: 0.83, blue: 0.42))
        _border = State(initialValue: option.borderColorHex
            .flatMap { ButtonColorValue(text: $0) }.map(ButtonColorAppearance.color)
            ?? Color(red: 0.63, green: 0.34, blue: 0.05))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CommunicationTile(item: previewItem, size: .large, highContrast: false,
                                      isScanHighlighted: false) {}
                        .frame(maxWidth: 220)
                        .allowsHitTesting(false)
                } header: { Text("Preview") }
                Section("Choice colors") {
                    Toggle("Custom background", isOn: $hasBackground)
                    if hasBackground {
                        ColorPicker("Background color", selection: $background, supportsOpacity: true)
                    }
                    Toggle("Custom border", isOn: $hasBorder)
                    if hasBorder {
                        ColorPicker("Border color", selection: $border, supportsOpacity: true)
                    }
                    Text("High contrast mode uses black and white buttons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(option.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(updatedOption)
                        dismiss()
                    }
                }
            }
        }
    }

    private var updatedOption: ChoiceOption {
        var updated = option
        updated.backgroundColorHex = hasBackground ? ButtonColorAppearance.hex(from: background) : nil
        updated.borderColorHex = hasBorder ? ButtonColorAppearance.hex(from: border) : nil
        return updated
    }

    private var previewItem: CommunicationItem { updatedOption.communicationItem }
}

private enum ChoiceScanTarget: Equatable {
    case option(UUID)
    case speakAgain
    case addToMessage
    case alternative(Int)
    case returnToSpeak
    case done
}

struct ChoiceBoardSessionView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let board: ChoiceBoard
    let onReturnToSpeak: () -> Void
    @State private var selectedOption: ChoiceOption?
    @State private var pendingOption: ChoiceOption?
    @State private var addedToMessage = false
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private var scanTargets: [ChoiceScanTarget] {
        var targets = board.options.map { ChoiceScanTarget.option($0.id) }
        if selectedOption != nil {
            targets.append(.speakAgain)
            if !addedToMessage { targets.append(.addToMessage) }
        }
        targets += [.alternative(0), .alternative(1), .returnToSpeak, .done]
        return targets
    }

    private var highlightedScanTarget: ChoiceScanTarget? {
        guard store.settings.scanEnabled, !scanTargets.isEmpty else { return nil }
        return scanTargets[min(scanIndex, scanTargets.count - 1)]
    }

    private var currentScanCue: ScanCue? {
        guard let highlightedScanTarget else { return nil }
        return ScanCue(text: scanLabel(for: highlightedScanTarget),
                       language: store.settings.communicationLanguage)
    }

    private var scanTimerID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanMode.rawValue)-\(store.settings.scanInterval)-\(board.id)"
    }

    private var alternatives: [ChoiceOption] {
        if store.settings.communicationLanguage == "es" {
            return [ChoiceOption(label: "Otra cosa", symbol: "❓"),
                    ChoiceOption(label: "No, gracias", symbol: "✋")]
        }
        return [ChoiceOption(label: "Something else", symbol: "❓"),
                ChoiceOption(label: "No thanks", symbol: "✋")]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.settings.scanEnabled { scanControlBar }
                else { QuickResponseBar() }
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(board.title)
                                .font(.largeTitle.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let selectedOption {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your choice")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text(store.displayLabel(for: selectedOption.communicationItem))
                                        .font(.title.bold())
                                        .accessibilityIdentifier("selected-choice")
                                    HStack {
                                        Button("Speak again", systemImage: "speaker.wave.2") {
                                            speak(selectedOption)
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(highlightedScanTarget == .speakAgain
                                                ? scanHighlightColor : .clear, lineWidth: 4))
                                        .id("choice-scan-speak-again")
                                        Button("Add to message", systemImage: "text.badge.plus") {
                                            addSelectedToMessage()
                                        }
                                        .disabled(addedToMessage)
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(highlightedScanTarget == .addToMessage
                                                ? scanHighlightColor : .clear, lineWidth: 4))
                                        .id("choice-scan-add-to-message")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            }
                            choiceTiles
                            Text("Another answer is always okay")
                                .font(.headline)
                            HStack(spacing: 12) {
                                ForEach(Array(alternatives.enumerated()), id: \.offset) { index, option in
                                    Button(option.label) { choose(option) }
                                        .buttonStyle(.borderedProminent)
                                        .frame(maxWidth: .infinity)
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(highlightedScanTarget == .alternative(index)
                                                ? scanHighlightColor : .clear, lineWidth: 4))
                                        .id("choice-scan-alternative-\(index)")
                                }
                            }
                            Button("Back to full Speak board") { onReturnToSpeak() }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(highlightedScanTarget == .returnToSpeak
                                        ? scanHighlightColor : .clear, lineWidth: 4))
                                .id("choice-scan-return")
                        }
                        .padding()
                    }
                    .onChange(of: highlightedScanTarget) { _, target in
                        if let target, let identifier = scanScrollID(for: target) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollProxy.scrollTo(identifier, anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Make a choice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("choice-session-done")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .done
                                ? scanHighlightColor : .clear, lineWidth: 4))
                }
            }
            .confirmationDialog("Choose \(pendingOption.map { store.displayLabel(for: $0.communicationItem) } ?? "this")?", isPresented: Binding(
                get: { pendingOption != nil }, set: { if !$0 { pendingOption = nil } }
            )) {
                Button("Choose") {
                    if let pendingOption { commit(pendingOption) }
                    pendingOption = nil
                }
                Button("Cancel", role: .cancel) { pendingOption = nil }
            }
            .onChange(of: currentScanCue, initial: true) { _, cue in
                if let cue { store.previewScanCue(cue) }
                else { store.stopScanCue() }
            }
            .task(id: scanTimerID) { await runScanTimer() }
            .onDisappear { store.stopScanCue() }
        }
    }

    private var scanHighlightColor: Color {
        store.settings.highContrast ? .black : .orange
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.settings.scanMode == .step ? "STEP SCAN · CHOICES" : "AUTO SCAN · CHOICES")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No choice")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("choice-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedChoice() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("choice-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") {
                        scanPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("choice-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("choice-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: ChoiceScanTarget) -> String {
        switch target {
        case .option(let id):
            guard let option = board.options.first(where: { $0.id == id }) else { return "Choice" }
            return store.displayLabel(for: option.resolved(using: store.items).communicationItem)
        case .speakAgain: return "Speak again"
        case .addToMessage: return "Add to message"
        case .alternative(let index):
            return alternatives.indices.contains(index) ? alternatives[index].label : "Another answer"
        case .returnToSpeak: return "Back to full Speak board"
        case .done: return "Done"
        }
    }

    private func scanScrollID(for target: ChoiceScanTarget) -> String? {
        switch target {
        case .option(let id): "choice-scan-option-\(id)"
        case .speakAgain: "choice-scan-speak-again"
        case .addToMessage: "choice-scan-add-to-message"
        case .alternative(let index): "choice-scan-alternative-\(index)"
        case .returnToSpeak: "choice-scan-return"
        case .done: nil
        }
    }

    private func advanceScan() {
        guard !scanTargets.isEmpty else { scanIndex = 0; return }
        scanIndex = (scanIndex + 1) % scanTargets.count
    }

    private func selectHighlightedChoice() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35,
              let highlightedScanTarget else { return }
        lastScanActivation = now
        switch highlightedScanTarget {
        case .option(let id):
            if let option = board.options.first(where: { $0.id == id }) {
                commit(option.resolved(using: store.items))
            }
        case .speakAgain:
            if let selectedOption { speak(selectedOption) }
        case .addToMessage:
            addSelectedToMessage()
        case .alternative(let index):
            if alternatives.indices.contains(index) { commit(alternatives[index]) }
        case .returnToSpeak: onReturnToSpeak()
        case .done: dismiss()
        }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active && !scanPaused && pendingOption == nil {
                advanceScan()
            }
        }
    }

    @ViewBuilder
    private var choiceTiles: some View {
        switch board.effectiveLayout {
        case .grid:
            choiceGrid(board.options)
        case .list:
            VStack(spacing: 12) {
                ForEach(board.options) { option in choiceTile(option, minimumHeight: 130) }
            }
        case .largeFirst:
            VStack(spacing: 12) {
                if let first = board.options.first {
                    choiceTile(first, minimumHeight: 205)
                }
                choiceGrid(Array(board.options.dropFirst()))
            }
        }
    }

    private func choiceGrid(_ options: [ChoiceOption]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(options) { option in choiceTile(option) }
        }
    }

    private func choiceTile(_ option: ChoiceOption, minimumHeight: CGFloat? = nil) -> some View {
        let current = option.resolved(using: store.items)
        return CommunicationTile(item: current.communicationItem, size: .large,
                                 highContrast: store.settings.highContrast,
                                 isScanHighlighted: highlightedScanTarget == .option(option.id),
                                 holdDuration: store.settings.wordHoldDuration,
                                 pointerDwellDuration: store.settings.pointerDwellDuration,
                                 minimumHeight: minimumHeight,
                                 displayLabel: store.displayLabel(for: current.communicationItem)) { choose(current) }
            .accessibilityAddTraits(selectedOption?.id == option.id ? .isSelected : [])
            .id("choice-scan-option-\(option.id)")
    }

    private func choose(_ option: ChoiceOption) {
        if store.settings.confirmSelection { pendingOption = option }
        else { commit(option) }
    }

    private func commit(_ option: ChoiceOption) {
        selectedOption = option
        addedToMessage = false
        if store.settings.scanEnabled,
           let index = scanTargets.firstIndex(of: .addToMessage) { scanIndex = index }
        speak(option)
    }

    private func addSelectedToMessage() {
        guard let selectedOption, !addedToMessage else { return }
        store.select(selectedOption.communicationItem)
        addedToMessage = true
        if store.settings.scanEnabled,
           let index = scanTargets.firstIndex(of: .speakAgain) { scanIndex = index }
    }

    private func speak(_ option: ChoiceOption) {
        if let audioData = option.audioData { store.playRecorded(audioData) }
        else { store.speak(store.displayMessage(for: option.communicationItem)) }
    }
}
