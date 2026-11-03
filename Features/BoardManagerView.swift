import SwiftUI
import UniformTypeIdentifiers

struct BoardManagerView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var renaming: String?
    @State private var renamedName = ""
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    @State private var renamingFolder: String?
    @State private var renamedFolderName = ""
    @State private var editingFolderVoice: BoardFolderVoiceTarget?
    @State private var errorMessage: String?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: OpenBoardDocument?
    @State private var exportType: UTType = .openBoardArchive
    @State private var exportName = "boards.obz"
    @State private var pendingImport: ImportedOpenBoards?
    @State private var showingImportConfirmation = false
    @State private var editingGrid: BoardGridEditorTarget?
    @State private var editingAppearance: BoardAppearanceTarget?
    @State private var showingBulkAdd = false
    @State private var showingQuickBoard = false
    @State private var showingLibrary = false
    @State private var showingQRImport = false
    @State private var sharingQRBoard: BoardQRTarget?

    var body: some View {
        NavigationStack {
            boardList
            .navigationTitle("Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add board", systemImage: "plus") { showingAdd = true }
                }
            }
            .alert("New board", isPresented: $showingAdd) {
                TextField("Board name", text: $newName)
                Button("Create") {
                    if !store.addBoard(newName) { errorMessage = "Use a unique board name." }
                    newName = ""
                }
                Button("Cancel", role: .cancel) { newName = "" }
            }
            .alert("Rename board", isPresented: Binding(
                get: { renaming != nil }, set: { if !$0 { renaming = nil } }
            )) {
                TextField("Board name", text: $renamedName)
                Button("Save") {
                    if let renaming, !store.renameBoard(renaming, to: renamedName) {
                        errorMessage = "Use a unique board name."
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .alert("New folder", isPresented: $showingAddFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    if !store.addBoardFolder(newFolderName) {
                        errorMessage = "Use a unique folder name of up to 40 characters."
                    }
                    newFolderName = ""
                }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
            .alert("Rename folder", isPresented: Binding(
                get: { renamingFolder != nil }, set: { if !$0 { renamingFolder = nil } }
            )) {
                TextField("Folder name", text: $renamedFolderName)
                Button("Save") {
                    if let renamingFolder, !store.renameBoardFolder(renamingFolder, to: renamedFolderName) {
                        errorMessage = "Use a unique folder name of up to 40 characters."
                    }
                    renamingFolder = nil
                }
                Button("Cancel", role: .cancel) { renamingFolder = nil }
            }
            .alert("Board error", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .fileExporter(isPresented: $showingExporter, document: exportDocument,
                          contentType: exportType, defaultFilename: exportName) { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.openBoard, .openBoardArchive]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { try? file.close() }
                    var data = Data()
                    while let chunk = try file.read(upToCount: min(1_048_576,
                        OpenBoardFormat.maxImportBytes + 1 - data.count)), !chunk.isEmpty {
                        data.append(chunk)
                        guard data.count <= OpenBoardFormat.maxImportBytes else { throw OpenBoardError.tooLarge }
                    }
                    pendingImport = try OpenBoardFormat.importData(data, fileExtension: url.pathExtension)
                    showingImportConfirmation = true
                } catch { errorMessage = error.localizedDescription }
            }
            .confirmationDialog(
                "Add \(pendingImport?.categories.count ?? 0) boards and \(pendingImport?.items.count ?? 0) buttons to \(store.activeProfileName)?",
                isPresented: $showingImportConfirmation
            ) {
                Button("Add boards") {
                    if let pendingImport { store.addOpenBoards(pendingImport) }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text(importWarnings)
            }
            .sheet(item: $editingGrid) { target in
                NavigationStack { BoardGridEditorView(boardName: target.name) }
                    .environmentObject(store)
            }
            .sheet(item: $editingAppearance) { target in
                BoardAppearanceView(boardName: target.name)
                    .environmentObject(store)
            }
            .sheet(item: $editingFolderVoice) { target in
                BoardFolderVoiceView(folder: target.name)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingBulkAdd) {
                BulkVocabularyView(initialBoard: store.categories.first ?? "Core")
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingQuickBoard) {
                BulkVocabularyView(initialBoard: store.categories.first ?? "Core", startsWithNewBoard: true)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingLibrary) {
                BoardLibraryView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingQRImport) {
                PageQRImportView()
                    .environmentObject(store)
            }
            .sheet(item: $sharingQRBoard) { target in
                PageQRShareView(boardName: target.name)
                    .environmentObject(store)
            }
        }
    }

    private var boardList: some View {
        List {
            Section {
                Text("Make boards for people, places, interests, or activities. Words stay on their board until you move them.")
                    .foregroundStyle(.secondary)
                Text("Tap a board to set its icon or hide it from the board bar. Pin boards to keep them in a separate strip while communicating.")
                    .foregroundStyle(.secondary)
            }
            Section("Shared grid") {
                NavigationLink {
                    BoardGridEditorView(boardName: nil)
                } label: {
                    LabeledContent("Default layout", value: gridDescription(store.settings.defaultBoardGridLayout))
                }
                .accessibilityIdentifier("default-grid-layout")
            }
            boardFoldersSection
            orderedBoardsSection
            Section("Library") {
                Button("Browse ready-made pages", systemImage: "books.vertical") {
                    showingLibrary = true
                }
                .accessibilityIdentifier("browse-board-library")
                Button("Import page QR", systemImage: "qrcode.viewfinder") {
                    showingQRImport = true
                }
                .accessibilityIdentifier("import-page-qr")
            }
            Section("Add vocabulary") {
                Button("Make a quick board", systemImage: "mic.fill") {
                    showingQuickBoard = true
                }
                .accessibilityIdentifier("board-quick-create")
                Button("Add several buttons", systemImage: "text.badge.plus") {
                    showingBulkAdd = true
                }
                .accessibilityIdentifier("board-bulk-add")
            }
            Section {
                Button("Import board file (.obf or .obz)", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                }
                .accessibilityIdentifier("import-open-board")
                Button("Export all boards (.obz)", systemImage: "square.and.arrow.up") {
                    do {
                        exportDocument = OpenBoardDocument(data: try store.openBoardArchiveData())
                        exportType = .openBoardArchive
                        exportName = "open-voice-boards.obz"
                        showingExporter = true
                    } catch { errorMessage = error.localizedDescription }
                }
                .accessibilityIdentifier("export-open-boards")
            } header: {
                Text("Open Board Format")
            } footer: {
                Text("Board files carry buttons, linked pages, photos, and button recordings. Use the profile backup in Settings to keep routines, drafts, and other personal data too.")
            }
        }
    }

    private var boardFoldersSection: some View {
        Section {
            ForEach(store.settings.boardFolders, id: \.self) { folder in
                HStack {
                    Label(folder, systemImage: "folder")
                    Spacer()
                    Text("\(store.categories.filter { store.boardFolder(for: $0) == folder }.count) boards")
                        .foregroundStyle(.secondary)
                    Menu("Options for folder \(folder)", systemImage: "ellipsis.circle") {
                        let index = store.settings.boardFolders.firstIndex(of: folder) ?? 0
                        Button("Move folder up", systemImage: "arrow.up") {
                            _ = store.moveBoardFolder(folder, by: -1)
                        }
                        .disabled(index == 0)
                        Button("Move folder down", systemImage: "arrow.down") {
                            _ = store.moveBoardFolder(folder, by: 1)
                        }
                        .disabled(index + 1 >= store.settings.boardFolders.count)
                        Button("Rename folder", systemImage: "pencil") {
                            renamingFolder = folder
                            renamedFolderName = folder
                        }
                        Button("Folder voice", systemImage: "waveform") {
                            editingFolderVoice = BoardFolderVoiceTarget(name: folder)
                        }
                        .accessibilityIdentifier("board-folder-voice-\(folder)")
                        Button("Remove folder", systemImage: "folder.badge.minus", role: .destructive) {
                            _ = store.deleteBoardFolder(folder)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("board-folder-options-\(folder)")
                }
            }
            Button("New folder", systemImage: "folder.badge.plus") { showingAddFolder = true }
                .accessibilityIdentifier("add-board-folder")
        } header: {
            Text("Board folders")
        } footer: {
            Text("Place boards in folders from each board’s options. Removing a folder keeps its boards and buttons.")
        }
    }

    private var orderedBoardsSection: some View {
        Section {
            ForEach(store.categories, id: \.self) { name in
                HStack {
                    boardAppearanceButton(for: name)
                    boardSizeMenu(for: name)
                    boardGridButton(for: name)
                    boardPinButton(for: name)
                    boardOptionsMenu(for: name)
                }
            }
            Button("Add a board", systemImage: "plus") { showingAdd = true }
        } header: {
            Text("Boards in navigation order")
        } footer: {
            Text("Use each board’s options to change its position. Move or delete a personal board’s buttons and incoming links before deleting the board.")
        }
    }

    private func boardOptionsMenu(for name: String) -> some View {
        let index = store.categories.firstIndex(of: name) ?? 0
        return Menu {
            Button("Move \(name) up", systemImage: "arrow.up") {
                _ = store.moveBoard(name, by: -1)
            }
            .disabled(index == 0)
            .accessibilityIdentifier("move-board-up-\(name)")
            Button("Move \(name) down", systemImage: "arrow.down") {
                _ = store.moveBoard(name, by: 1)
            }
            .disabled(index + 1 >= store.categories.count)
            .accessibilityIdentifier("move-board-down-\(name)")
            Button("Export board (.obf)", systemImage: "square.and.arrow.up") {
                exportBoard(name)
            }
            Button("Share page QR", systemImage: "qrcode") {
                sharingQRBoard = BoardQRTarget(name: name)
            }
            .accessibilityIdentifier("share-page-qr-\(name)")
            Menu("Move to folder", systemImage: "folder") {
                Button("No folder", systemImage: store.boardFolder(for: name) == nil ? "checkmark" : "circle") {
                    _ = store.setBoardFolder(nil, for: name)
                }
                ForEach(store.settings.boardFolders, id: \.self) { folder in
                    Button(folder, systemImage: store.boardFolder(for: name) == folder ? "checkmark" : "folder") {
                        _ = store.setBoardFolder(folder, for: name)
                    }
                }
            }
            .accessibilityIdentifier("assign-board-folder-\(name)")
            if !StarterVocabulary.categories.contains(name) {
                Button("Rename", systemImage: "pencil") {
                    renaming = name
                    renamedName = name
                }
                if buttonCount(in: name) == 0 && linkCount(to: name) == 0 {
                    Button("Delete empty board", systemImage: "trash", role: .destructive) {
                        _ = store.deleteBoard(name)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Options for \(name)")
        .accessibilityIdentifier("board-options-\(name)")
    }

    private func buttonCount(in name: String) -> Int {
        store.items.filter { $0.category == name }.count
    }

    private func boardAppearanceButton(for name: String) -> some View {
        Button {
            editingAppearance = BoardAppearanceTarget(name: name)
        } label: {
            BoardRowView(name: name, count: buttonCount(in: name),
                         sizeDescription: sizeDescription(for: name), icon: store.boardIcon(for: name),
                         isVisible: store.visibleBoards.contains(name))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("board-appearance-\(name)")
        .accessibilityHint("Edit icon and board bar visibility")
    }

    private func boardSizeMenu(for name: String) -> some View {
        Menu {
            Button {
                store.setTileSize(nil, for: name)
            } label: {
                Label("Use default", systemImage: store.settings.boardTileSizes[name] == nil ? "checkmark" : "circle")
            }
            ForEach(TileSize.allCases, id: \.self) { size in
                Button {
                    store.setTileSize(size, for: name)
                } label: {
                    Label(sizeLabel(size), systemImage: store.settings.boardTileSizes[name] == size ? "checkmark" : "circle")
                }
            }
        } label: {
            Label("Button size for \(name)", systemImage: "square.grid.2x2")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("board-size-\(name)")
        .accessibilityValue(store.settings.boardTileSizes[name].map(sizeLabel) ?? "Default")
    }

    private func sizeLabel(_ size: TileSize) -> String {
        switch size {
        case .compact: "Compact"
        case .standard: "Standard"
        case .large: "Large"
        }
    }

    private func sizeDescription(for name: String) -> String {
        let buttonSize = store.settings.boardTileSizes[name].map { "\(sizeLabel($0)) buttons" }
            ?? "Default button size"
        let folder = store.boardFolder(for: name).map { " · Folder: \($0)" } ?? ""
        return "\(buttonSize) · \(gridDescription(store.gridLayout(for: name)))\(folder)"
    }

    private func gridDescription(_ layout: BoardGridLayout?) -> String {
        layout.map { "\($0.columns)×\($0.rows) grid" } ?? "Auto grid"
    }

    private func boardGridButton(for name: String) -> some View {
        Button("Grid for \(name)", systemImage: "rectangle.grid.3x3") {
            editingGrid = BoardGridEditorTarget(name: name)
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("board-grid-\(name)")
        .accessibilityValue(gridDescription(store.gridLayout(for: name)))
    }

    private func boardPinButton(for name: String) -> some View {
        Button(store.settings.pinnedBoards.contains(name) ? "Unpin \(name)" : "Pin \(name)",
               systemImage: store.settings.pinnedBoards.contains(name) ? "pin.fill" : "pin") {
            store.setBoardPinned(!store.settings.pinnedBoards.contains(name), board: name)
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("pin-board-\(name)")
        .accessibilityValue(store.settings.pinnedBoards.contains(name) ? "Pinned" : "Not pinned")
    }

    private func linkCount(to name: String) -> Int {
        store.items.filter { $0.destinationBoard == name }.count
    }

    private var importWarnings: String {
        guard let pendingImport else { return "Existing boards and other profile data stay in place." }
        var details = ["Existing boards and other profile data stay in place. Name conflicts get an imported suffix."]
        if pendingImport.skippedActions > 0 {
            details.append("\(pendingImport.skippedActions) action buttons cannot be used here and will be skipped.")
        }
        if pendingImport.missingLinks > 0 {
            details.append("\(pendingImport.missingLinks) unresolved board links will be skipped.")
        }
        if pendingImport.missingMedia > 0 {
            details.append("\(pendingImport.missingMedia) unavailable images or sounds will be omitted.")
        }
        return details.joined(separator: " ")
    }

    private func exportBoard(_ name: String) {
        do {
            exportDocument = OpenBoardDocument(data: try store.openBoardData(named: name))
            exportType = .openBoard
            exportName = "\(name.replacingOccurrences(of: "/", with: "-")).obf"
            showingExporter = true
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct BoardRowView: View {
    let name: String
    let count: Int
    let sizeDescription: String
    let icon: String?
    let isVisible: Bool

    var body: some View {
        HStack {
            if let icon {
                Text(icon)
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(sizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !isVisible {
                    Text("Hidden from board bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(count) buttons")
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

private struct BoardGridEditorTarget: Identifiable {
    let name: String
    var id: String { name }
}

private struct BoardAppearanceTarget: Identifiable {
    let name: String
    var id: String { name }
}

private struct BoardQRTarget: Identifiable {
    let name: String
    var id: String { name }
}

private struct BoardFolderVoiceTarget: Identifiable {
    let name: String
    var id: String { name }
}

private struct BoardFolderVoiceView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var voiceCatalog = SpeechVoiceCatalog.shared
    let folder: String
    @State private var searchText = ""

    private var voices: [SpeechVoiceOption] {
        voiceCatalog.voices
            .filter { $0.language.hasPrefix(store.settings.communicationLanguage) }
            .filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        _ = store.setBoardFolderVoiceIdentifier(nil, for: folder)
                        dismiss()
                    } label: {
                        Label("Use profile voice", systemImage: currentIdentifier.isEmpty
                              ? "checkmark.circle.fill" : "circle")
                    }
                    .accessibilityIdentifier("folder-voice-profile")
                } footer: {
                    Text("Buttons in this folder use its voice when spoken or when their picture message is read aloud. Recordings on individual buttons still play as recorded.")
                }
                Section("Installed voices") {
                    if voices.isEmpty {
                        Text("Installed voices for the current communication language appear here when iOS finishes loading them.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(voices) { voice in
                        Button {
                            _ = store.setBoardFolderVoiceIdentifier(voice.identifier, for: folder)
                            dismiss()
                        } label: {
                            HStack {
                                Text(voice.name)
                                if voice.isPersonalVoice { Text("Personal").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if voice.identifier == currentIdentifier { Image(systemName: "checkmark") }
                            }
                        }
                        .accessibilityIdentifier("folder-voice-\(voice.identifier)")
                    }
                }
                if !currentIdentifier.isEmpty,
                   !voiceCatalog.voices.contains(where: { $0.identifier == currentIdentifier &&
                       $0.language.hasPrefix(store.settings.communicationLanguage) }) {
                    Section {
                        Text("The saved voice is unavailable for the current language. This folder uses the profile voice until that voice is available again or you choose another.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Voice for \(folder)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .searchable(text: $searchText, prompt: "Find a voice")
            .onAppear { voiceCatalog.refresh() }
        }
    }

    private var currentIdentifier: String {
        store.settings.boardFolderVoiceIdentifiers[folder] ?? ""
    }
}

private struct BoardGridEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftLayout: BoardGridLayout?
    let boardName: String?

    private var savedLayout: BoardGridLayout? {
        if let boardName { return store.settings.boardGridLayouts[boardName] }
        return store.settings.defaultBoardGridLayout
    }

    private var inheritedLayout: BoardGridLayout? {
        boardName == nil ? nil : store.settings.defaultBoardGridLayout
    }

    private var selectedLayout: BoardGridLayout? { draftLayout }

    var body: some View {
        Form {
            Section {
                Button(selectedLayout == nil ? "Set a fixed grid"
                       : (boardName == nil ? "Use automatic grid" : "Use shared grid")) {
                    setLayout(selectedLayout == nil
                              ? (inheritedLayout ?? BoardGridLayout(columns: 3, rows: 4)) : nil)
                }
                .accessibilityIdentifier("grid-mode")
                if selectedLayout != nil {
                    Picker("Columns", selection: Binding(
                        get: { selectedLayout?.columns ?? 3 },
                        set: { setLayout(BoardGridLayout(columns: $0, rows: selectedLayout?.rows ?? 4)) }
                    )) {
                        ForEach(1...BoardGridLayout.maximumColumns, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    .accessibilityIdentifier("grid-columns")
                    Picker("Rows", selection: Binding(
                        get: { selectedLayout?.rows ?? 4 },
                        set: { setLayout(BoardGridLayout(columns: selectedLayout?.columns ?? 3, rows: $0)) }
                    )) {
                        ForEach(1...BoardGridLayout.maximumRows, id: \.self) { count in Text("\(count)").tag(count) }
                    }
                    .accessibilityIdentifier("grid-rows")
                    if let selectedLayout {
                        Text("\(selectedLayout.pageCapacity) button positions per page")
                            .foregroundStyle(.secondary)
                    }
                } else if let inheritedLayout {
                    Text("Uses the shared \(inheritedLayout.columns)×\(inheritedLayout.rows) grid.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Columns adjust automatically to the screen and button size. All buttons scroll on one board.")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Fixed grids keep each button in its numbered position. Extra buttons continue on the next page. Narrow screens can scroll sideways to reach every column.")
            }
        }
        .navigationTitle(boardName.map { "\($0) grid" } ?? "Shared grid")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draftLayout = savedLayout }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    private func setLayout(_ layout: BoardGridLayout?) {
        draftLayout = layout
        if let boardName { store.setGridLayout(layout, for: boardName) }
        else { store.setDefaultGridLayout(layout) }
    }
}
