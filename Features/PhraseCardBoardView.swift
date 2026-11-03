import SwiftUI
import UIKit

private enum PhraseCardFolder: Hashable {
    case all
    case quick
    case recent
    case named(String)

    init(link: PhraseFolderLink) {
        switch link {
        case .quick: self = .quick
        case .named(let name): self = .named(name)
        }
    }

    var gridScope: String {
        switch self {
        case .all: "all"
        case .quick: "quick"
        case .recent: "recent"
        case .named(let name): "folder:\(name)"
        }
    }

    var title: String {
        switch self {
        case .all: "All phrases"
        case .quick: "Quick communication"
        case .recent: "Recent phrases"
        case .named(let name): name
        }
    }
}

struct PhraseCardBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    let openKeyboard: () -> Void
    @State private var selectedFolder: PhraseCardFolder
    @State private var searchText = ""
    @State private var fillingPhrase: SavedPhrase?
    @State private var editingPhrase: SavedPhrase?
    @State private var movingPhrase: SavedPhrase?
    @State private var movingFromPosition = 0
    @State private var audioSharePayload: AudioSharePayload?
    @State private var audioShareError = ""
    @State private var showingAudioShareError = false
    @State private var sharingAudioPhraseID: UUID?
    @State private var showingGridEditor = false
    @State private var gridPage = 0
    @ScaledMetric(relativeTo: .body) private var minimumCardWidth: CGFloat = 164

    init(openKeyboard: @escaping () -> Void, initialFolderLink: PhraseFolderLink? = nil) {
        self.openKeyboard = openKeyboard
        _selectedFolder = State(initialValue: initialFolderLink.map(PhraseCardFolder.init(link:)) ?? .all)
    }

    private var folders: [String] {
        Array(Set(store.phrases.compactMap(\.folder)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var visiblePhrases: [SavedPhrase] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = selectedFolder == .recent ? store.recentPhrases : store.phrases
        return source.filter { phrase in
            let inFolder: Bool
            switch selectedFolder {
            case .all: inFolder = true
            case .quick: inFolder = phrase.folder == nil
            case .recent: inFolder = true
            case .named(let folder): inFolder = phrase.folder == folder
            }
            return inFolder && (query.isEmpty || phrase.text.localizedStandardContains(query)
                                || (phrase.label?.localizedStandardContains(query) ?? false)
                                || (phrase.folder?.localizedStandardContains(query) ?? false))
        }
    }

    private var selectedGridLayout: BoardGridLayout? {
        selectedFolder == .recent ? nil : store.settings.phraseCardGridLayouts[selectedFolder.gridScope]
    }

    var body: some View {
        let visible = visiblePhrases
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tap a card to speak, add it to text, or open a linked folder. Fill-in phrases open a form first. Touch and hold to change card order.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if selectedFolder != .all {
                    Text(selectedFolder.title)
                        .font(.headline)
                        .accessibilityIdentifier("phrase-card-current-folder")
                }
                if visible.isEmpty {
                    ContentUnavailableView("No phrases here", systemImage: "rectangle.grid.2x2",
                                           description: Text("Add a phrase in Quick phrases or choose another folder."))
                } else {
                    cardGrid(visible)
                }
                if visible.contains(where: { $0.arasaacPictogramID != nil }) {
                    Text(ARASAACPictogramService.attribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.bottom, 110)
        }
        .navigationTitle("Phrase cards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if selectedFolder != .recent {
                    Button("Grid", systemImage: "square.grid.3x3") { showingGridEditor = true }
                        .accessibilityIdentifier("phrase-card-grid-settings")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Folder", selection: $selectedFolder) {
                    Text("All phrases").tag(PhraseCardFolder.all)
                    Text("Quick communication").tag(PhraseCardFolder.quick)
                    if store.settings.recentPhrasesEnabled {
                        Text("Recent phrases").tag(PhraseCardFolder.recent)
                    }
                    ForEach(folders, id: \.self) { folder in
                        Text(folder).tag(PhraseCardFolder.named(folder))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("phrase-card-folder")
            }
        }
        .searchable(text: $searchText, prompt: "Find a phrase")
        .sheet(isPresented: $showingGridEditor) {
            PhraseCardGridEditorView(scopeKey: selectedFolder.gridScope, scopeTitle: selectedFolder.title)
                .environmentObject(store)
        }
        .sheet(item: $fillingPhrase) { phrase in
            PhraseTemplateFillView(phrase: phrase) { completed in
                if store.appendTypedPhrase(completed, joinBehavior: phrase.joinBehavior) {
                    store.recordRecentPhrase(phrase)
                    openKeyboard()
                }
            }
        }
        .sheet(item: $editingPhrase) { PhraseTextEditorView(phrase: $0) }
        .fullScreenCover(item: $movingPhrase) { phrase in
            PhraseCardPositionEditorView(phrase: phrase, scopeKey: selectedFolder.gridScope,
                                         initialPosition: movingFromPosition) { target in
                if let layout = selectedGridLayout { gridPage = target / layout.pageCapacity }
            }
            .environmentObject(store)
        }
        .sheet(item: $audioSharePayload) { AudioShareSheet(url: $0.url) }
        .alert("Couldn't share audio", isPresented: $showingAudioShareError) {
            Button("OK", role: .cancel) {}
        } message: { Text(audioShareError) }
        .onChange(of: store.activeProfileID) { _, _ in
            selectedFolder = .all
            searchText = ""
            fillingPhrase = nil
            editingPhrase = nil
            movingPhrase = nil
            audioSharePayload = nil
            showingAudioShareError = false
            showingGridEditor = false
            gridPage = 0
        }
        .onChange(of: selectedFolder) { _, _ in gridPage = 0 }
        .onChange(of: searchText) { _, _ in gridPage = 0 }
        .onChange(of: store.settings.recentPhrasesEnabled) { _, enabled in
            if !enabled && selectedFolder == .recent { selectedFolder = .all }
        }
    }

    @ViewBuilder
    private func cardGrid(_ visible: [SavedPhrase]) -> some View {
        if let layout = selectedGridLayout,
           searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let emptyPositions = Set(store.settings.phraseCardEmptySlots[selectedFolder.gridScope] ?? [])
            let slots = PhraseCardSlotLayout.slots(for: visible, emptyPositions: emptyPositions)
            let pageCount = layout.pageCount(for: slots.count)
            let currentPage = min(gridPage, pageCount - 1)
            let range = layout.range(for: currentPage, itemCount: slots.count)
            let pageSlots = Array(slots[range])
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("\(layout.columns) columns × \(layout.rows) rows")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("phrase-grid-size")
                    Spacer()
                    if pageCount > 1 {
                        Button("Previous page", systemImage: "chevron.left") {
                            gridPage = max(0, currentPage - 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(currentPage == 0)
                        .accessibilityIdentifier("phrase-grid-previous-page")
                        Text("Page \(currentPage + 1) of \(pageCount)")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("phrase-grid-page-count")
                        Button("Next page", systemImage: "chevron.right") {
                            gridPage = min(pageCount - 1, currentPage + 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(currentPage == pageCount - 1)
                        .accessibilityIdentifier("phrase-grid-next-page")
                    }
                }
                ScrollView(.horizontal) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(minimumCardWidth), spacing: 12),
                                             count: layout.columns), spacing: 12) {
                        ForEach(0..<layout.pageCapacity, id: \.self) { position in
                            let absolutePosition = range.lowerBound + position
                            if position < pageSlots.count, let phrase = pageSlots[position] {
                                phraseCard(phrase, gridPosition: absolutePosition)
                                    .frame(width: minimumCardWidth)
                                    .accessibilityValue("Grid position \(absolutePosition + 1)")
                            } else if emptyPositions.contains(absolutePosition) {
                                Text("Empty \(absolutePosition + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: minimumCardWidth, height: 200)
                                    .background(Color(uiColor: .systemGray6).opacity(0.5),
                                                in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .strokeBorder(Color.secondary.opacity(0.4),
                                                      style: StrokeStyle(lineWidth: 1, dash: [5])))
                                    .accessibilityLabel("Empty grid position \(absolutePosition + 1)")
                            } else {
                                Color.clear.frame(width: minimumCardWidth, height: 200)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(width: CGFloat(layout.columns) * minimumCardWidth
                           + CGFloat(layout.columns - 1) * 12)
                }
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCardWidth, maximum: 250),
                                         spacing: 12)], spacing: 12) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, phrase in
                    phraseCard(phrase)
                        .accessibilityValue("Card \(index + 1) of \(visible.count)")
                }
            }
        }
    }

    private func phraseCard(_ phrase: SavedPhrase, gridPosition: Int? = nil) -> some View {
        let isTemplate = !PhraseTemplate.fields(in: phrase.text).isEmpty
        let tapAction = phrase.effectiveTapAction(fallback: store.settings.phraseTapAction)
        let appearance = store.settings.highContrast ? nil : phrase.colorHex.flatMap(ButtonColorValue.init(text:))
        let background = appearance.map(ButtonColorAppearance.color)
            ?? Color(uiColor: .systemGray6)
        return Button {
            if let link = phrase.folderLink, store.phraseFolderLinkOptions.contains(link) {
                selectedFolder = PhraseCardFolder(link: link)
                searchText = ""
            } else if isTemplate { fillingPhrase = phrase }
            else if tapAction == .speak { store.speakPhrase(phrase) }
            else if store.appendTypedPhrase(phrase) { openKeyboard() }
        } label: {
            VStack(spacing: 10) {
                if let data = phrase.imageData {
                    AsyncThumbnailImage(data: data) {
                        Image(systemName: phrase.folderLink != nil ? "folder.fill" : isTemplate ? "text.badge.plus" :
                              (phrase.audioData == nil ? "speaker.wave.2.fill" : "waveform"))
                            .font(.system(size: 42))
                    }
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: phrase.folderLink != nil ? "folder.fill" : isTemplate ? "text.badge.plus" :
                          (phrase.audioData == nil ? "speaker.wave.2.fill" : "waveform"))
                        .font(.system(size: 42))
                        .frame(height: 100)
                }
                Text(phrase.displayLabel)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if let link = phrase.folderLink {
                    Label(link.title, systemImage: "arrow.turn.down.right")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                if let languageCode = phrase.languageCode {
                    Label(languageCode, systemImage: "globe")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                if phrase.tapActionOverride != nil {
                    Label(tapAction.title, systemImage: tapAction == .speak
                          ? "speaker.wave.2" : "keyboard")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                if phrase.joinBehavior != .normal {
                    Text(phrase.joinBehavior == .prefix ? "Prefix" : "Suffix")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 176)
            .padding(12)
            .foregroundStyle(appearance?.prefersDarkText == false ? Color.white : Color.primary)
            .background(background, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(store.settings.highContrast ? Color.primary : Color.primary.opacity(0.12),
                              lineWidth: store.settings.highContrast ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(phrase.accessibleLabel)
        .accessibilityIdentifier("phrase-card-\(phrase.id)")
        .accessibilityHint(phrase.folderLink.map { "Open \($0.title) folder" } ?? (isTemplate ? "Fill in this phrase" :
                           (tapAction == .insertTyped ? "Add to the typed draft and open Keyboard"
                            : (phrase.audioData == nil ? "Speak with the system voice" : "Play the recorded voice"))))
        .contextMenu {
            Button("Edit phrase", systemImage: "pencil") { editingPhrase = phrase }
            if let gridPosition {
                Button("Move to grid position", systemImage: "square.grid.3x3") {
                    movingFromPosition = gridPosition
                    movingPhrase = phrase
                }
            }
            if selectedFolder != .recent {
                Button("Move earlier", systemImage: "arrow.up") { store.movePhrase(phrase, by: -1) }
                    .disabled(!store.canMovePhrase(phrase, by: -1))
                Button("Move later", systemImage: "arrow.down") { store.movePhrase(phrase, by: 1) }
                    .disabled(!store.canMovePhrase(phrase, by: 1))
            }
            if !isTemplate && phrase.folderLink == nil {
                ShareLink(item: phrase.text) {
                    Label("Share text", systemImage: "doc.on.doc")
                }
                Button("Share audio", systemImage: "waveform") { prepareAudioShare(phrase) }
                    .disabled(sharingAudioPhraseID != nil)
            }
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

private struct PhraseCardGridEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let scopeKey: String
    let scopeTitle: String

    private var layout: BoardGridLayout? { store.settings.phraseCardGridLayouts[scopeKey] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(layout == nil ? "Use fixed grid" : "Use automatic grid") {
                        store.setPhraseCardGridLayout(layout == nil
                            ? BoardGridLayout(columns: 3, rows: 4) : nil, for: scopeKey)
                    }
                    .accessibilityIdentifier("phrase-grid-mode")
                    if let layout {
                        Picker("Columns", selection: Binding(
                            get: { layout.columns },
                            set: { store.setPhraseCardGridLayout(
                                BoardGridLayout(columns: $0, rows: layout.rows), for: scopeKey) }
                        )) {
                            ForEach(1...BoardGridLayout.maximumColumns, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .accessibilityIdentifier("phrase-grid-columns")
                        Picker("Rows", selection: Binding(
                            get: { layout.rows },
                            set: { store.setPhraseCardGridLayout(
                                BoardGridLayout(columns: layout.columns, rows: $0), for: scopeKey) }
                        )) {
                            ForEach(1...BoardGridLayout.maximumRows, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .accessibilityIdentifier("phrase-grid-rows")
                        Text("\(layout.pageCapacity) card \(layout.pageCapacity == 1 ? "position" : "positions") per page")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Cards adjust to the available screen width.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(scopeTitle)
                } footer: {
                    Text("Fixed grids keep cards in order, continue on another page when full, and scroll sideways on narrow screens.")
                }
            }
            .navigationTitle("Phrase card grid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PhraseCardPositionEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var positionFocused: Bool
    @State private var positionText: String
    let phrase: SavedPhrase
    let scopeKey: String
    let onMove: (Int) -> Void

    init(phrase: SavedPhrase, scopeKey: String, initialPosition: Int,
         onMove: @escaping (Int) -> Void) {
        self.phrase = phrase
        self.scopeKey = scopeKey
        self.onMove = onMove
        _positionText = State(initialValue: String(initialPosition + 1))
    }

    private var target: Int? {
        guard let number = Int(positionText),
              (1...BoardSlotLayout.maximumEditablePosition).contains(number) else { return nil }
        return number - 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Grid position", text: $positionText)
                        .keyboardType(.numberPad)
                        .focused($positionFocused)
                        .accessibilityIdentifier("phrase-grid-position-input")
                    Button("Move card") { commitMove() }
                        .disabled(target == nil)
                        .accessibilityIdentifier("phrase-grid-confirm-move")
                } header: {
                    Text(phrase.displayLabel)
                } footer: {
                    Text("Enter a position from 1 to \(BoardSlotLayout.maximumEditablePosition). Moving to an occupied position swaps the two cards. Empty positions remain available for future phrases.")
                }
            }
            .navigationTitle("Move phrase card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done typing") { positionFocused = false }
                }
            }
        }
    }

    private func commitMove() {
        guard let target, store.movePhraseCard(phrase, to: target, in: scopeKey) else { return }
        onMove(target)
        dismiss()
    }
}
