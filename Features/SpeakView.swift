import AVFoundation
import SwiftUI

private struct ScanCueState: Equatable {
    let active: Bool
    let mode: ScanCueMode
    let target: ScanTarget?
    let pendingWordID: UUID?
    let language: String
    let voiceIdentifier: String
}

private struct MessageButtonDraft: Identifiable {
    let id = UUID()
    let text: String
    let category: String
    let language: String
}

struct SpeakView: View {
    @EnvironmentObject private var store: CommunicationStore
    @EnvironmentObject private var nearby: NearbyChatService
    @EnvironmentObject private var callAudio: CallAudioManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigator = BoardNavigator()
    @State private var timeHighlightHour = Calendar.current.component(.hour, from: Date())
    @State private var scanner = BoardScanner()
    @State private var boardAvailableWidth: CGFloat = 400
    @State private var boardPageIndex = 0
    @State private var selectedBoardCluster: Int?
    @State private var isVisible = false
    @State private var hasOpenedHomeBoard = false
    @State private var repeatTapFilter = RepeatTapFilter()
    @State private var pendingScanWordID: UUID?
    @State private var lastScanActivation = Date.distantPast
    @State private var search = ""
    @State private var exploringAllWords = false
    @State private var finderTargetID: UUID?
    @Binding var isTyping: Bool
    @State private var showingAdd = false
    @State private var showingBulkAdd = false
    @State private var messageButtonDraft: MessageButtonDraft?
    @State private var targetButtonDraft: MessageButtonDraft?
    @State private var showingBoards = false
    @State private var showingBoardOrder = false
    @State private var showingPaintButtons = false
    @State private var showingProfiles = false
    @State private var showingPassport = false
    @State private var showingChoices = false
    @State private var showingScenes = false
    @State private var selectedScene: VisualSceneBoard?
    @State private var showingWordManager = false
    @State private var showingWordFinder = false
    @State private var editingItem: CommunicationItem?
    @State private var playingVideoItem: CommunicationItem?
    @State private var webPageItem: CommunicationItem?
    @State private var phraseItem: CommunicationItem?
    @State private var pendingItem: CommunicationItem?
    @State private var showingMessage = false
    @State private var showingTypedMessage = false
    @State private var showingExpandedTyping = false
    @State private var showingAttention = false
    @State private var showingNearbyChat = false
    @State private var showingCallAudio = false
    @State private var showingNearbySendError = false
    @State private var nearbySendError = ""
    @State private var showingConversations = false
    @State private var showingNotes = false
    @State private var showingFocus = false
    @State private var showingPracticeSetup = false
    @State private var practiceSession: PracticeSession?
    @State private var showingDrawing = false
    @State private var showingSoundBoard = false
    @State private var showingSpeechToPictures = false
    @State private var showingListeningReply = false
    @State private var showingReadAloud = false
    @State private var showingAlphabetKeyboard = false
    @State private var showingSingleButton = false
    @State private var showingBedside = false
    @State private var showingLanyard = false
    @State private var showingSpeechVolume = false
    @State private var showingWordForms = false
    @State private var showingCommunicationRepair = false
    @State private var typedWordFormContext: TypedWordForms.Context?
    @State private var showingBoardOnlyUnlock = false
    @State private var fillingShortcutPhrase: SavedPhrase?
    @State private var focusActive = false
    @State private var audioSharePayload: AudioSharePayload?
    @State private var isPreparingAudioShare = false
    @State private var showingAudioShareError = false
    @State private var audioShareError = ""

    private var focusedWordIDs: Set<UUID> {
        focusActive ? Set(store.settings.focusWordIDs) : []
    }

    private var effectiveTileSize: TileSize { store.tileSize(for: navigator.currentBoard) }

    private var coreTileSize: TileSize { store.tileSize(for: "Core") }

    private var currentBoardUsesTyping: Bool {
        store.items.contains {
            $0.category == navigator.currentBoard
                && $0.boardVisibility != .hidden && $0.effectiveAction.isTypingAction
        }
    }

    private var currentBoardHasPredictionKeys: Bool {
        store.items.contains {
            $0.category == navigator.currentBoard
                && $0.boardVisibility != .hidden
                && $0.effectiveAction == .completeTypedPrediction
        }
    }

    private var effectiveGridLayout: BoardGridLayout? {
        guard search.isEmpty && !usesGroupedPictureBoard else { return nil }
        return store.gridLayout(for: navigator.currentBoard)
    }

    private var boardColumnCount: Int {
        if let effectiveGridLayout { return effectiveGridLayout.columns }
        return BoardScanner.columnCount(availableWidth: boardAvailableWidth,
                                        minimumTileWidth: effectiveTileSize.minimumWidth)
    }

    private var boardPageCount: Int {
        guard let effectiveGridLayout else { return 1 }
        return effectiveGridLayout.pageCount(for: allBoardSlots.count)
    }

    private var currentBoardPage: Int { min(boardPageIndex, boardPageCount - 1) }

    private var allBoardSlots: [CommunicationItem?] {
        guard search.isEmpty && !usesGroupedPictureBoard && store.categories.contains(navigator.currentBoard) else {
            return displayedItems.map(Optional.some)
        }
        return BoardSlotLayout.slots(for: displayedItems,
                                     emptyPositions: store.emptyGridPositions(in: navigator.currentBoard))
    }

    private var boardPageSlots: [CommunicationItem?] {
        guard let effectiveGridLayout else { return allBoardSlots }
        let page = Array(allBoardSlots[effectiveGridLayout.range(for: currentBoardPage,
                                                                 itemCount: allBoardSlots.count)])
        return page + Array(repeating: nil, count: effectiveGridLayout.pageCapacity - page.count)
    }

    private var boardGridContentWidth: CGFloat {
        guard let effectiveGridLayout else { return max(0, boardAvailableWidth - 32) }
        return max(boardAvailableWidth - 32,
                   CGFloat(effectiveGridLayout.columns) * effectiveTileSize.minimumWidth
                   + CGFloat(effectiveGridLayout.columns - 1) * 10)
    }

    private var finderPageIndex: Int {
        guard let effectiveGridLayout, let finderTargetID,
              let position = allBoardSlots.firstIndex(where: { $0?.id == finderTargetID }) else { return 0 }
        return position / effectiveGridLayout.pageCapacity
    }

    private var finderTarget: CommunicationItem? {
        guard let finderTargetID else { return nil }
        return store.items.first {
            $0.id == finderTargetID
                && $0.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
        }
    }

    private var recentBoardName: String {
        var name = "Recent"
        while store.categories.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            name += " (Open Voice)"
        }
        return name
    }

    private var finderBanner: some View {
        HStack(spacing: 8) {
            if let target = finderTarget {
                let onTargetBoard = navigator.currentBoard == target.category
                let groupedTarget = usesGroupedPictureBoard && onTargetBoard
                Label(onTargetBoard
                      ? (groupedTarget && selectedBoardCluster == nil
                         ? "Step 2: Choose the highlighted group"
                         : "\(groupedTarget ? "Step 3" : "Step 2"): Select \(store.displayLabel(for: target))")
                      : "Step 1: Choose \(target.category)", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("finder-step")
            }
            Spacer(minLength: 4)
            Button("End find") { finderTargetID = nil }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("end-word-finder")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(store.settings.highContrast ? Color.white : Color.pink.opacity(0.12))
    }

    private func startFinding(_ id: UUID) {
        guard let target = store.items.first(where: {
            $0.id == id && $0.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
        }) else { return }
        search = ""
        isTyping = false
        navigator.goTo(store.visibleBoards.contains(target.category) ? "Core" : target.category)
        finderTargetID = id
    }

    private func focusBoardContains(_ name: String) -> Bool {
        store.items.contains { item in
            focusedWordIDs.contains(item.id)
                && item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
                && (name == recentBoardName
                    || ProgressiveVocabulary.isAvailable(item, stage: store.settings.progressiveVocabularyStage,
                                                        exploring: exploringAllWords))
                && (name == "Favorites" ? item.isFavorite
                    : (name == recentBoardName ? store.settings.recentPictureWordIDs.contains(item.id)
                       && store.settings.recentPictureWordsEnabled : item.category == name))
        }
    }

    private func suggestedBoardContains(_ name: String, ids: Set<UUID>) -> Bool {
        store.items.contains { item in
            ids.contains(item.id)
                && (name == "Favorites" ? item.isFavorite
                    : (name == recentBoardName ? store.settings.recentPictureWordIDs.contains(item.id)
                       && store.settings.recentPictureWordsEnabled : item.category == name))
        }
    }

    private var visibleItems: [CommunicationItem] {
        if search.isEmpty && navigator.currentBoard == recentBoardName { return store.recentPictureItems }
        let source = search.isEmpty ? store.items.filter { $0.category == navigator.currentBoard } : store.items.filter {
            $0.boardVisibility != .hidden &&
                ($0.label.localizedCaseInsensitiveContains(search) || $0.message.localizedCaseInsensitiveContains(search)
                 || store.displayLabel(for: $0).localizedCaseInsensitiveContains(search))
        }
        return source
    }

    private var displayedItems: [CommunicationItem] {
        let items = navigator.currentBoard == "Favorites" && search.isEmpty
            ? store.items.filter(\.isFavorite) : visibleItems
        guard search.isEmpty && navigator.currentBoard != "Favorites"
                && navigator.currentBoard != recentBoardName else { return items }
        return items.map {
            ProgressiveVocabulary.displayed($0, stage: store.settings.progressiveVocabularyStage,
                                            exploring: exploringAllWords || finderTargetID == $0.id)
        }
    }

    private var usesGroupedPictureBoard: Bool {
        store.settings.groupedPictureBoard && !store.settings.scanEnabled && search.isEmpty
    }

    private var showsPersistentCore: Bool {
        store.settings.twoBoardsEnabled && !store.settings.scanEnabled && search.isEmpty
            && navigator.currentBoard != "Core" && !currentBoardUsesTyping
    }

    private var persistentCoreItems: [CommunicationItem] {
        store.items.filter { $0.category == "Core" }.map {
            ProgressiveVocabulary.displayed($0, stage: store.settings.progressiveVocabularyStage,
                                            exploring: exploringAllWords || finderTargetID == $0.id)
        }
    }

    private var persistentCoreSlots: [CommunicationItem?] {
        BoardSlotLayout.slots(for: persistentCoreItems,
                              emptyPositions: store.emptyGridPositions(in: "Core"))
    }

    private var boardClusters: [BoardWordCluster] {
        BoardWordCluster.groups(for: displayedItems)
    }

    private var quickWords: [CommunicationItem] {
        ["yes", "no", "help", "break"].compactMap { word in
            store.items.first { $0.label == word }
        }.filter { $0.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive) }
    }

    private var suggestedBoardWordIDs: Set<UUID> {
        guard store.settings.showBoardSuggestions else { return [] }
        let candidates = store.localizedItems(excludingPredictionKeys: true).filter {
            $0.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
                && ProgressiveVocabulary.isAvailable($0, stage: store.settings.progressiveVocabularyStage,
                                                    exploring: exploringAllWords)
        }
        return Set(WordPrediction.boardItemIDs(
            after: store.composedMessage, items: candidates, phrases: store.phrases,
            history: store.settings.saveHistory ? store.history : [],
            learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
            language: store.settings.communicationLanguage))
    }

    private var progressiveVocabularyBanner: some View {
        HStack(spacing: 8) {
            Label(exploringAllWords ? "Exploring all words" : store.settings.progressiveVocabularyStage.title,
                  systemImage: exploringAllWords ? "square.grid.3x3.fill" : "square.grid.3x3")
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 4)
            Button(exploringAllWords ? "Return to stage" : "Explore all") {
                exploringAllWords.toggle()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("explore-vocabulary")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.1))
    }

    private var scanTargets: [ScanTarget] {
        guard store.settings.scanEnabled else { return [] }
        let pageSlots = boardPageSlots
        let targets = scanner.targets(quickWords: currentBoardUsesTyping ? [] : quickWords.map(scanningItem),
                                      boardItems: pageSlots.compactMap { $0 }.map(scanningItem),
                                      emptyPositions: Set(pageSlots.indices.filter { pageSlots[$0] == nil }),
                                      boards: store.visibleBoards + (store.settings.recentPictureWordsEnabled ? [recentBoardName] : []),
                                      hasBack: !navigator.history.isEmpty,
                                      hasMessage: !currentBoardUsesTyping && !store.messageParts.isEmpty,
                                      pattern: store.settings.scanPattern, columns: boardColumnCount,
                                      hasPreviousPage: currentBoardPage > 0,
                                      hasNextPage: currentBoardPage + 1 < boardPageCount,
                                      dimmedButtonsActive: store.settings.dimmedButtonsActive)
        return store.isBoardOnlyModeActive
            ? targets.filter { $0 != .conversations && $0 != .focusWords }
            : targets
    }

    private var highlightedTarget: ScanTarget? {
        guard store.settings.scanEnabled else { return nil }
        return scanner.highlighted(in: scanTargets)
    }

    private var scanCueBlockedByPresentation: Bool {
        showingAdd || showingBulkAdd || showingBoards || showingBoardOrder || showingPaintButtons
            || showingProfiles || showingPassport || showingChoices
            || showingScenes || selectedScene != nil || showingWordManager || showingWordFinder
            || editingItem != nil || phraseItem != nil
            || pendingItem != nil || showingMessage || showingTypedMessage || showingAttention
            || showingExpandedTyping
            || showingConversations || showingNotes || showingFocus || showingPracticeSetup
            || showingDrawing || showingSpeechToPictures
            || showingListeningReply
            || showingReadAloud
            || showingAlphabetKeyboard
            || showingSingleButton || showingWordForms || showingCommunicationRepair || showingBoardOnlyUnlock
            || showingLanyard
            || showingSpeechVolume
            || showingNearbyChat
            || showingCallAudio
            || fillingShortcutPhrase != nil
    }

    private var scanCueState: ScanCueState {
        ScanCueState(active: isVisible && scenePhase == .active && !isTyping && !scanner.isPaused
                         && !scanCueBlockedByPresentation
                         && store.settings.scanEnabled && store.settings.scanCueMode != .off,
                     mode: store.settings.scanCueMode,
                     target: highlightedTarget, pendingWordID: pendingScanWordID,
                     language: store.settings.communicationLanguage,
                     voiceIdentifier: store.settings.scanCueVoiceIdentifier)
    }

    private var scanTimerID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanMode.rawValue)-\(store.settings.scanPattern.rawValue)-\(store.settings.scanInterval)-\(isTyping)-\(scenePhase)-\(navigator.currentBoard)-\(search)"
    }

    private var scanHighlightColor: Color { store.settings.highContrast ? .black : .orange }

    private var scanGroupTitle: String {
        if scanner.group == .words {
            switch store.settings.scanPattern {
            case .sequential: return "WORDS"
            case .rowColumn: return "ROWS"
            case .columnRow: return "COLUMNS"
            }
        }
        if scanner.group == .line {
            return "\(store.settings.scanPattern == .columnRow ? "COLUMN" : "ROW") \(scanner.selectedLine + 1) BUTTONS"
        }
        return scanner.group.title.uppercased()
    }

    var body: some View {
        NavigationStack {
            screenStateful
        }
    }

    private var screenBase: some View {
        VStack(spacing: 0) {
                if let invitation = nearby.pendingInvitation {
                    HStack {
                        Text("Nearby: \(invitation.displayName) wants to connect")
                        Spacer()
                        Button("Decline") { nearby.answerInvitation(accept: false) }
                        Button("Connect") { nearby.answerInvitation(accept: true) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("nearby-invitation-banner")
                } else if nearby.unreadCount > 0 {
                    Button("\(nearby.unreadCount) new nearby \(nearby.unreadCount == 1 ? "message" : "messages")", systemImage: "bubble.left.fill") {
                        showingNearbyChat = true
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .accessibilityIdentifier("nearby-unread")
                }
                if callAudio.isCallAvailable {
                    Button {
                        showingCallAudio = true
                    } label: {
                        Label(callAudio.isEnabled ? "Open Voice audio is in this call" : "Add Open Voice audio to this call",
                              systemImage: "phone.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("call-audio-banner")
                }
                if store.settings.saveHistory || store.settings.learnPrediction { historyControlBar }
                if !isTyping { MessagePlaybackControl() }
                if practiceSession != nil { practiceBanner }
                if isTyping {
                    typingPanel
                } else {
                    if currentBoardUsesTyping { gridTypingBar } else { messageBar }
                    if store.settings.scanEnabled { scanControlBar }
                    picturePanel
                }
            }
            .background(store.settings.highContrast ? Color.white : Color(red: 0.98, green: 0.98, blue: 1))
            .navigationTitle(practiceSession == nil ? "Open Voice" : "Practice")
            .navigationBarTitleDisplayMode(practiceSession == nil ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Get attention", systemImage: "bell.fill") { showingAttention = true }
                        .accessibilityIdentifier("get-attention")
                        .overlay(Capsule().strokeBorder(
                            isScanHighlighted(.attention) ? scanHighlightColor : .clear,
                            lineWidth: 4))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listen and reply", systemImage: "ear.badge.waveform") {
                        showingListeningReply = true
                    }
                    .accessibilityIdentifier("open-listening-reply")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Word finder", systemImage: "magnifyingglass") {
                        showingWordFinder = true
                    }
                    .accessibilityHint("Practice the board path to a picture word")
                    .accessibilityIdentifier("open-word-finder")
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !isTyping && horizontalSizeClass != .regular {
                        Button("Communication repair", systemImage: "arrow.uturn.backward") {
                            showingCommunicationRepair = true
                        }
                        .accessibilityHint("Speak a phrase without changing your message")
                        .accessibilityIdentifier("open-communication-repair")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isBoardOnlyModeActive {
                        Button("Leave board-only mode", systemImage: "lock.fill") {
                            showingBoardOnlyUnlock = true
                        }
                        .accessibilityIdentifier("board-only-unlock")
                    } else {
                    Menu {
                        Button("Add button", systemImage: "plus") { showingAdd = true }
                        Button("Add several buttons", systemImage: "text.badge.plus") { showingBulkAdd = true }
                        Button("Add spelling board", systemImage: "textformat.abc") {
                            if let board = store.addSpellingBoard() {
                                navigator.goTo(board)
                                search = ""
                            }
                        }
                        .accessibilityIdentifier("add-spelling-board")
                        Button("Add QWERTY-order board", systemImage: "keyboard") {
                            if let board = store.addSpellingBoard(layout: .qwerty) {
                                navigator.goTo(board)
                                search = ""
                            }
                        }
                        .accessibilityIdentifier("add-qwerty-board")
                        Button("Manage boards", systemImage: "square.grid.2x2") { showingBoards = true }
                        Button("Arrange buttons", systemImage: "arrow.up.arrow.down") { showingBoardOrder = true }
                        Button("Paint buttons", systemImage: "paintpalette") { showingPaintButtons = true }
                        Button("Edit words", systemImage: "pencil") { showingWordManager = true }
                        Button("Switch profile", systemImage: "person.2") { showingProfiles = true }
                        Button("My communication passport", systemImage: "person.text.rectangle") { showingPassport = true }
                        Button("Choice boards", systemImage: "square.grid.2x2") { showingChoices = true }
                        Button("Scenes", systemImage: "photo.on.rectangle") { showingScenes = true }
                        Button("Focus words", systemImage: "scope") { showingFocus = true }
                        Button("Practice together", systemImage: "person.2") {
                            showingPracticeSetup = true
                        }
                        .accessibilityIdentifier("open-practice")
                        Button("Drawing board", systemImage: "scribble.variable") { showingDrawing = true }
                        Button("Sound board", systemImage: "waveform") { showingSoundBoard = true }
                            .accessibilityIdentifier("open-sound-board")
                        Button("Speech to pictures", systemImage: "mic.fill") {
                            showingSpeechToPictures = true
                        }
                        Button("Read aloud", systemImage: "doc.text.magnifyingglass") {
                            showingReadAloud = true
                        }
                        .accessibilityIdentifier("open-read-aloud")
                        Button("Nearby chat", systemImage: "bubble.left.and.bubble.right") {
                            showingNearbyChat = true
                        }
                        Button("Call audio", systemImage: "phone.arrow.up.right") {
                            showingCallAudio = true
                        }
                        Button("One button mode", systemImage: "speaker.wave.3.fill") { showingSingleButton = true }
                        Button(store.settings.twoBoardsEnabled ? "Use one board" : "Keep Core beside topic",
                               systemImage: "rectangle.split.2x1") {
                            store.settings.twoBoardsEnabled.toggle()
                        }
                        .accessibilityIdentifier("customize-two-boards")
                        if store.visibleBoards.contains(navigator.currentBoard) {
                            Button(store.homeBoard == navigator.currentBoard
                                   ? "Current home board: \(navigator.currentBoard)"
                                   : "Make \(navigator.currentBoard) home board",
                                   systemImage: "house") {
                                store.setHomeBoard(navigator.currentBoard)
                            }
                            .accessibilityIdentifier("customize-set-home-board")
                        }
                    } label: {
                        Label("Customize", systemImage: "plus")
                    }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isTyping ? "Pictures" : "Keyboard", systemImage: isTyping ? "square.grid.2x2" : "keyboard") {
                        if isTyping { store.stopSpeaking() }
                        isTyping.toggle()
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ItemEditorView(item: nil, category: navigator.currentBoard == "Favorites" ? "Core" : navigator.currentBoard)
            }
            .sheet(isPresented: $showingBulkAdd) {
                BulkVocabularyView(initialBoard: store.categories.contains(navigator.currentBoard)
                                   ? navigator.currentBoard : "Core")
            }
            .sheet(item: $messageButtonDraft) { draft in
                ItemEditorView(item: nil, category: draft.category, initialMessage: draft.text)
            }
            .sheet(item: $targetButtonDraft) { draft in
                MessageButtonTargetPicker(message: draft.text, language: draft.language)
            }
            .fullScreenCover(isPresented: $showingAlphabetKeyboard) {
                AlphabetKeyboardView()
            }
            .fullScreenCover(isPresented: $showingSingleButton) {
                SingleButtonView()
            }
            .fullScreenCover(isPresented: $showingBedside) {
                BedsideView()
            }
            .fullScreenCover(isPresented: $showingLanyard) {
                LanyardView(initialBoard: navigator.currentBoard)
            }
            .sheet(isPresented: $showingSpeechVolume) { SpeechVolumeView() }
            .sheet(isPresented: $showingWordForms) { WordFormsView() }
            .sheet(isPresented: $showingCommunicationRepair) { CommunicationRepairView() }
            .sheet(item: $typedWordFormContext) { context in
                TypedWordFormsView(context: context) { option in
                    guard let result = TypedWordForms.replacing(store.typedMessage, context: context,
                                                                with: option) else { return }
                    store.typedMessage = result.text
                    store.typedCursorOffset = result.cursorOffset
                }
            }
            .sheet(isPresented: $showingBoardOnlyUnlock) { BoardOnlyUnlockView() }
            .sheet(isPresented: $showingBoards) { BoardManagerView() }
            .sheet(isPresented: $showingBoardOrder) {
                BoardOrderView(board: navigator.currentBoard, availableWidth: boardAvailableWidth)
            }
            .sheet(isPresented: $showingPaintButtons) {
                PaintBoardView(initialBoard: navigator.currentBoard)
            }
            .sheet(isPresented: $showingProfiles) { ProfileManagerView() }
            .sheet(isPresented: $showingPassport) { CommunicationPassportView() }
            .sheet(isPresented: $showingChoices) { ChoiceBoardsView() }
            .sheet(isPresented: $showingScenes) { SceneBoardsView() }
            .sheet(item: $selectedScene) { scene in
                SceneSessionView(board: scene) { selectedScene = nil }
            }
            .sheet(isPresented: $showingWordManager) { WordManagerView() }
            .sheet(isPresented: $showingWordFinder) {
                BoardWordFinderView(onChoose: startFinding)
            }
            .sheet(item: $editingItem) { ItemEditorView(item: $0, category: $0.category) }
            .sheet(item: $playingVideoItem) { SceneHotspotVideoView(item: $0) }
            .sheet(item: $webPageItem) { item in
                if let url = ButtonWebLink.url(item.webURL) {
                    ButtonWebPageView(title: store.displayLabel(for: item), url: url)
                }
            }
            .sheet(item: $phraseItem) { item in
                CardPhraseChoicesView(item: item) {
                    commitSelection(item)
                } onUsePhrase: { phrase in
                    if repeatTapFilter.allows(item.id, interval: store.settings.repeatFilterInterval) {
                        store.selectPhrase(phrase, from: item.id)
                        navigator.selectWord()
                    }
                }
            }
            .sheet(isPresented: $showingMessage) {
                MessageDisplayView(message: store.composedMessage, isPictureMessage: true)
            }
            .sheet(isPresented: $showingTypedMessage) { MessageDisplayView(message: store.typedMessage) }
            .fullScreenCover(isPresented: $showingExpandedTyping) { ExpandedTypingView() }
            .sheet(isPresented: $showingNearbyChat) { NearbyChatView() }
            .sheet(isPresented: $showingCallAudio) {
                NavigationStack { CallAudioView(isModal: true) }
            }
            .alert("Couldn't send nearby", isPresented: $showingNearbySendError) {
                Button("OK", role: .cancel) {}
            } message: { Text(nearbySendError) }
            .sheet(item: $audioSharePayload) { AudioShareSheet(url: $0.url) }
            .alert("Couldn't share audio", isPresented: $showingAudioShareError) {
                Button("OK", role: .cancel) {}
            } message: { Text(audioShareError) }
            .sheet(isPresented: $showingAttention) { AttentionAlertView() }
            .sheet(isPresented: $showingConversations) { ConversationDraftsView() }
            .sheet(isPresented: $showingNotes) {
                CommunicationNotesView(onUseInDraft: { isTyping = true })
            }
            .sheet(isPresented: $showingFocus) { FocusWordsView(isActive: $focusActive) }
            .sheet(isPresented: $showingPracticeSetup) {
                PracticeSetupView { activity in
                    practiceSession = PracticeSession(activity: activity)
                }
            }
            .sheet(isPresented: $showingDrawing) { DrawingBoardView() }
            .sheet(isPresented: $showingSoundBoard) { SoundBoardView() }
            .sheet(isPresented: $showingSpeechToPictures) { SpeechToPictureView(isTyping: $isTyping) }
            .sheet(isPresented: $showingListeningReply) { ListeningReplyView() }
            .sheet(isPresented: $showingReadAloud) { ReadAloudView() }
            .sheet(item: $fillingShortcutPhrase) { phrase in
                PhraseTemplateFillView(phrase: phrase) { completed in
                    setTypedMessageAndCaret(PhraseShortcut.expanding(store.typedMessage, with: completed))
                }
            }
            .confirmationDialog(pendingItem?.effectiveAction == .playVideo
                ? "Play \(pendingItem.map(store.displayLabel(for:)) ?? "video")?"
                : pendingItem?.effectiveAction == .openWebPage
                    ? "Open \(pendingItem.map(store.displayLabel(for:)) ?? "web page")?"
                    : pendingItem?.effectiveAction == .openScene
                        ? "Open \(pendingItem.map(store.displayLabel(for:)) ?? "scene")?"
                        : pendingItem?.effectiveAction == .openKeyboard
                            ? "Open typing keyboard?"
                    : pendingItem?.effectiveAction == .typeText
                        ? "Type \(pendingItem.map(store.displayLabel(for:)) ?? "text")?"
                    : pendingItem?.effectiveAction.isTypingAction == true
                        ? "\(pendingItem?.effectiveAction.title ?? "Use key")?"
                    : "Add \(pendingItem.map(store.displayLabel(for:)) ?? "word") to your message?", isPresented: Binding(
                get: { pendingItem != nil }, set: { if !$0 { pendingItem = nil } }
            )) {
                Button(pendingItem?.effectiveAction == .playVideo ? "Play video"
                       : pendingItem?.effectiveAction == .openWebPage ? "Open page"
                       : pendingItem?.effectiveAction == .openScene ? "Open scene"
                       : pendingItem?.effectiveAction == .openKeyboard ? "Open keyboard"
                       : pendingItem?.effectiveAction.isTypingAction == true ? "Use key" : "Add word") {
                    if let pendingItem { commitSelection(pendingItem) }
                    pendingItem = nil
                }
                Button("Cancel", role: .cancel) { pendingItem = nil }
            }
    }

    private var screenStateful: some View {
        screenBase
            .onChange(of: store.categories) { _, boards in
                navigator.reconcile(availableBoards: boards
                    + (store.settings.recentPictureWordsEnabled ? [recentBoardName] : []),
                    homeBoard: store.homeBoard)
            }
            .onChange(of: store.settings.recentPictureWordsEnabled) { _, enabled in
                navigator.reconcile(availableBoards: store.categories + (enabled ? [recentBoardName] : []),
                                    homeBoard: store.homeBoard)
                scanner.enter(.words)
            }
            .onChange(of: navigator.currentBoard) { _, _ in
                pendingScanWordID = nil
                scanner.enter(.words)
                selectedBoardCluster = nil
                boardPageIndex = finderPageIndex
            }
            .onChange(of: search) { _, _ in
                pendingScanWordID = nil
                selectedBoardCluster = nil
                boardPageIndex = 0
            }
            .onChange(of: finderTargetID) { _, _ in
                boardPageIndex = finderPageIndex
            }
            .onChange(of: store.settings.progressiveVocabularyStage) { _, _ in
                exploringAllWords = false
                pendingScanWordID = nil
                selectedBoardCluster = nil
            }
            .onChange(of: scanTargets) { _, targets in
                scanner.reconcile(targetCount: targets.count)
            }
            .onChange(of: store.settings.scanEnabled) { _, _ in
                scanner.reset()
                pendingScanWordID = nil
                selectedBoardCluster = nil
                lastScanActivation = .distantPast
            }
            .onChange(of: store.settings.groupedPictureBoard) { _, _ in
                selectedBoardCluster = nil
            }
            .onChange(of: store.settings.scanMode) { _, _ in
                scanner.reset()
                pendingScanWordID = nil
                lastScanActivation = .distantPast
            }
            .onChange(of: store.settings.scanPattern) { _, _ in
                scanner.reset()
                pendingScanWordID = nil
                lastScanActivation = .distantPast
            }
            .onChange(of: store.activeProfileID) { _, _ in
                navigator = BoardNavigator()
                navigator.goTo(store.homeBoard)
                scanner.reset()
                pendingScanWordID = nil
                lastScanActivation = .distantPast
                search = ""
                selectedBoardCluster = nil
                exploringAllWords = false
                finderTargetID = nil
                boardPageIndex = 0
                isTyping = false
                pendingItem = nil
                phraseItem = nil
                playingVideoItem = nil
                webPageItem = nil
                messageButtonDraft = nil
                targetButtonDraft = nil
                repeatTapFilter.reset()
                focusActive = false
                practiceSession = nil
            }
            .onChange(of: store.activeConversationID) { _, _ in
                scanner.enter(.words)
                pendingScanWordID = nil
                pendingItem = nil
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    callAudio.refresh()
                    timeHighlightHour = Calendar.current.component(.hour, from: Date())
                }
            }
            .onAppear {
                if !hasOpenedHomeBoard {
                    navigator.goTo(store.homeBoard)
                    hasOpenedHomeBoard = true
                }
                isVisible = true
                callAudio.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.microphoneInjectionCapabilitiesChangeNotification)) { _ in
                callAudio.refresh()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                let hour = Calendar.current.component(.hour, from: date)
                if hour != timeHighlightHour { timeHighlightHour = hour }
            }
            .onDisappear {
                isVisible = false
                store.stopScanCue()
            }
            .onChange(of: scanCueState, initial: true) { previous, current in
                updateScanCue(previous: previous, current: current)
            }
            .task(id: scanTimerID) {
                await runScanTimer()
            }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic,
              !isTyping else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active && !scanner.isPaused && pendingScanWordID == nil {
                scanner.advance(targetCount: scanTargets.count)
            }
        }
    }

    private func updateScanCue(previous: ScanCueState, current: ScanCueState) {
        guard current.active, let target = current.target else {
            store.stopScanCue()
            return
        }
        if previous.pendingWordID != nil && current.pendingWordID == nil && previous.target == target {
            return
        }
        if let id = current.pendingWordID,
           let item = store.items.first(where: { $0.id == id }) {
            store.previewScanCue(.forConfirmation(store.displayLabel(for: item), language: current.language))
        } else {
            store.previewScanCue(.forTarget(target, language: current.language))
        }
    }

    private var historyControlBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.settings.historyPaused
                     ? (store.settings.saveHistory && !store.settings.learnPrediction ? "History paused" : "Saving paused") :
                     (store.settings.saveHistory && store.settings.learnPrediction
                      ? "History and learning on" : (store.settings.saveHistory ? "Recent messages on" : "Learning on")))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("history-pause-status")
                Text(store.settings.historyPaused
                     ? (store.settings.saveHistory && !store.settings.learnPrediction
                        ? "New spoken messages are not saved" : "New spoken messages are not saved or learned")
                     : (store.settings.saveHistory && store.settings.learnPrediction
                        ? "Messages and word patterns stay on this device"
                        : (store.settings.saveHistory ? "Spoken messages are saved on this device"
                           : "Word patterns are learned on this device")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(store.settings.historyPaused ? "Resume" : "Pause") {
                store.settings.historyPaused.toggle()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(store.settings.saveHistory && store.settings.learnPrediction
                                ? (store.settings.historyPaused
                                   ? "Resume message history and word learning"
                                   : "Pause message history and word learning")
                                : (store.settings.saveHistory
                                   ? (store.settings.historyPaused ? "Resume message history" : "Pause message history")
                                   : (store.settings.historyPaused ? "Resume word learning" : "Pause word learning")))
            .accessibilityIdentifier("toggle-history-pause")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(store.settings.highContrast ? Color.white
                    : (store.settings.historyPaused ? Color.orange.opacity(0.16)
                       : Color(red: 0.93, green: 0.94, blue: 1)))
    }

    private var gridTypingBar: some View {
        let suggestions = WordPrediction.suggestions(
            for: store.typedMessage, items: store.localizedItems(excludingPredictionKeys: true), phrases: store.phrases,
            history: store.settings.saveHistory ? store.history : [],
            learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
            language: store.settings.communicationLanguage)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Typed message")
                    .font(.headline)
                Spacer()
                speechVolumeButton
                Menu {
                    Button("English") { switchBoardLanguage(to: "en") }
                    Button("Español") { switchBoardLanguage(to: "es") }
                } label: {
                    Label(store.settings.communicationLanguage == "es" ? "ES" : "EN",
                          systemImage: "globe")
                }
                .accessibilityIdentifier("grid-keyboard-language")
                Button("Full keyboard", systemImage: "keyboard") { isTyping = true }
                    .accessibilityIdentifier("grid-keyboard-full")
            }
            Text(gridTypedMessageDisplay)
                .font(.title3.weight(.medium))
                .foregroundStyle(store.typedMessage.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .accessibilityLabel("Typed message: \(store.typedMessage.isEmpty ? "empty" : store.typedMessage)")
                .accessibilityValue("Cursor \(typedCursorOffset ?? 0) of \(store.typedMessage.count)")
                .accessibilityIdentifier("grid-typed-message")
            if let highlight = store.speechHighlight, highlight.source == .typed {
                SpeechFollowAlongView(state: highlight)
            }
            if !currentBoardHasPredictionKeys && typedCursorOffset == store.typedMessage.count
                && !suggestions.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(suggestions, id: \.self) { word in
                            Button(word) {
                                setTypedMessageAndCaret(WordPrediction.completing(store.typedMessage, with: word))
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("grid-prediction-\(word.lowercased())")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            HStack(spacing: 10) {
                Button("Speak", systemImage: "speaker.wave.2.fill") {
                    store.speak(store.typedMessage, saveToHistory: true, followAlong: .typed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("grid-speak-typed")
                Spacer(minLength: 0)
                Button("Show", systemImage: "rectangle.expand.vertical") {
                    showingTypedMessage = true
                }
                .labelStyle(.iconOnly)
                .disabled(store.typedMessage.isEmpty)
                Button("Delete", systemImage: "delete.left") {
                    let offset = typedCursorOffset ?? store.typedMessage.count
                    if offset > 0 {
                        store.typedMessage = String(store.typedMessage.prefix(offset).dropLast())
                            + String(store.typedMessage.dropFirst(offset))
                        store.typedCursorOffset = offset - 1
                    }
                }
                .labelStyle(.iconOnly)
                .disabled((typedCursorOffset ?? 0) == 0)
                .accessibilityIdentifier("grid-delete-typed")
                Button("Clear", systemImage: "xmark") {
                    store.stopSpeaking()
                    store.typedMessage = ""
                    store.typedCursorOffset = 0
                }
                .labelStyle(.iconOnly)
                .disabled(store.typedMessage.isEmpty)
                .accessibilityIdentifier("grid-clear-typed")
            }
        }
        .padding()
        .background(store.settings.highContrast ? Color.white : Color(red: 0.93, green: 0.94, blue: 1))
    }

    private var messageBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if !store.isBoardOnlyModeActive {
                    Button(store.activeConversationName, systemImage: "bubble.left.and.bubble.right") {
                        showingConversations = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityHint("Switch or create a conversation without losing this draft")
                    .accessibilityIdentifier("open-conversations")
                }
                Spacer()
                speechVolumeButton
                Button("Notes", systemImage: "note.text") { showingNotes = true }
                    .buttonStyle(.bordered)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("open-notes")
                Menu {
                    Button("English") { switchBoardLanguage(to: "en") }
                    Button("Español") { switchBoardLanguage(to: "es") }
                } label: {
                    Label(store.settings.communicationLanguage == "es" ? "ES" : "EN", systemImage: "globe")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Board language, \(store.settings.communicationLanguage == "es" ? "Spanish" : "English")")
                .accessibilityIdentifier("board-language")
                Button("Choice boards", systemImage: "square.grid.2x2") { showingChoices = true }
                    .buttonStyle(.bordered)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Choice boards")
            }
            Text(store.composedMessage.isEmpty ? "Tap words to build a message" : store.composedMessage)
                .font(.title3.weight(.medium))
                .foregroundStyle(store.composedMessage.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .accessibilityLabel("Message: \(store.composedMessage.isEmpty ? "empty" : store.composedMessage)")
            if let highlight = store.speechHighlight, highlight.source == .picture {
                SpeechFollowAlongView(state: highlight)
            }
            HStack(spacing: 10) {
                Button("Speak", systemImage: "speaker.wave.2.fill") { store.speakMessage() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.composedMessage.isEmpty)
                    .accessibilityIdentifier("speak-picture-message")
                Spacer(minLength: 0)
                Button("Word forms", systemImage: "textformat") { showingWordForms = true }
                    .labelStyle(.iconOnly)
                    .disabled(store.lastWordFormOptions.isEmpty)
                    .accessibilityHint("Change the last supported picture word")
                    .accessibilityIdentifier("word-forms")
                if horizontalSizeClass == .regular {
                    Button("Communication repair", systemImage: "arrow.uturn.backward") {
                        showingCommunicationRepair = true
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("Speak a phrase without changing your message")
                    .accessibilityIdentifier("picture-communication-repair")
                }
                if store.canUndoClearMessage {
                    Button { 
                        store.undoClearMessage()
                    } label: { Image(systemName: "arrow.uturn.backward.circle") }
                    .accessibilityLabel("Undo clear message")
                    .accessibilityIdentifier("undo-clear-message")
                } else {
                    Button { store.removeLast() } label: { Image(systemName: "arrow.uturn.backward") }
                        .accessibilityLabel("Undo last word")
                        .disabled(store.messageParts.isEmpty)
                }
                Button { store.clearMessage() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Clear message")
                    .disabled(store.messageParts.isEmpty)
                Menu {
                    Button("Show large message", systemImage: "rectangle.expand.vertical") { showingMessage = true }
                    Button("Change last word form", systemImage: "textformat") { showingWordForms = true }
                        .disabled(store.lastWordFormOptions.isEmpty)
                    Button("Communication repair", systemImage: "arrow.uturn.backward") {
                        showingCommunicationRepair = true
                    }
                    .accessibilityIdentifier("message-communication-repair")
                    ShareLink(item: store.composedMessage) { Label("Share message", systemImage: "square.and.arrow.up") }
                    if !nearby.connectedPeers.isEmpty {
                        Button("Send nearby", systemImage: "bubble.left.and.bubble.right") {
                            sendNearby(store.composedMessage, pictureTokens: store.pictureMessageTokens)
                        }
                    }
                    Button("Nearby chat", systemImage: "bubble.left.and.bubble.right") {
                        showingNearbyChat = true
                    }
                    Button("Share audio", systemImage: "waveform") {
                        prepareAudioShare(store.composedMessage, isPictureMessage: true)
                    }
                    .disabled(isPreparingAudioShare)
                    .accessibilityIdentifier("share-picture-audio")
                    if !store.isBoardOnlyModeActive {
                        Button("Save as quick phrase", systemImage: "star") { store.addPhrase(store.composedMessage) }
                        Button("Save as button", systemImage: "plus.square") {
                            messageButtonDraft = MessageButtonDraft(
                                text: store.composedMessage,
                                category: navigator.currentBoard == "Favorites" ? "Core" : navigator.currentBoard,
                                language: store.settings.communicationLanguage)
                        }
                        Button("Store on existing button", systemImage: "square.and.pencil") {
                            targetButtonDraft = MessageButtonDraft(
                                text: store.composedMessage,
                                category: navigator.currentBoard == "Favorites" ? "Core" : navigator.currentBoard,
                                language: store.settings.communicationLanguage)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .disabled(store.composedMessage.isEmpty)
                .accessibilityIdentifier("picture-message-more")
            }
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .controlSize(.regular)
        }
        .padding()
        .background(store.settings.highContrast ? Color.white : Color(red: 0.93, green: 0.94, blue: 1))
    }

    private var speechVolumeButton: some View {
        Button("Speech volume", systemImage: store.settings.speechMuted
               ? "speaker.slash.fill" : "speaker.wave.2.fill") {
            showingSpeechVolume = true
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .accessibilityLabel(store.settings.speechMuted ? "Speech muted, adjust volume" : "Adjust speech volume")
        .accessibilityValue(store.settings.speechMuted
                            ? "Muted" : "\(Int(store.settings.speechVolume * 100)) percent")
        .accessibilityIdentifier("open-speech-volume")
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(store.settings.scanMode == .step ? "STEP SCAN" : "AUTO SCAN") · \(scanGroupTitle)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(pendingScanWordID.flatMap { id in store.items.first { $0.id == id }.map(store.displayLabel(for:)) }
                 .map { "Select again to add \($0)" } ?? (highlightedTarget?.label ?? "No choice"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlighted() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityLabel(pendingScanWordID == nil ? "Select highlighted" : "Confirm highlighted word")
                    .accessibilityIdentifier("scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanner.isPaused ? "Resume" : "Pause",
                           systemImage: scanner.isPaused ? "play.fill" : "pause.fill") {
                        scanner.isPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(scanner.isPaused ? "Resume scanning" : "Pause scanning")
                    .accessibilityIdentifier("scan-pause")
                }
                Button("Next", systemImage: "arrow.right") {
                    pendingScanWordID = nil
                    scanner.advance(targetCount: scanTargets.count)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("n", modifiers: [])
                .accessibilityLabel("Next scan target")
                .accessibilityIdentifier("scan-next")
            }
            .frame(maxWidth: .infinity)
            .controlSize(.large)
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func boardGrid(suggestedIDs: Set<UUID>) -> some View {
        let timeIDs = store.timeOfDayHighlightIDs(for: navigator.currentBoard, hour: timeHighlightHour)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                 count: boardColumnCount), spacing: 10) {
            ForEach(Array(boardPageSlots.enumerated()), id: \.offset) { entry in
                if let item = entry.element {
                    boardItemCell(item, position: entry.offset, suggestedIDs: suggestedIDs,
                                  timeOfDayIDs: timeIDs)
                } else {
                    hiddenBoardSlot(position: entry.offset)
                }
            }
        }
    }

    private func boardTabTitle(_ name: String) -> String {
        guard let icon = store.boardIcon(for: name) else { return name }
        return "\(icon) \(name)"
    }

    @ViewBuilder
    private var practiceBanner: some View {
        if let practiceSession {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Label(practiceSession.activity.title(language: store.settings.communicationLanguage),
                          systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer(minLength: 4)
                    Text("Idea \(practiceSession.ideaIndex + 1) of \(practiceSession.activity.ideas(language: store.settings.communicationLanguage).count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(practiceSession.turn == .partner ? "Partner's turn" : "Your turn")
                    .font(.subheadline.weight(.semibold))
                Text(practiceSession.prompt(language: store.settings.communicationLanguage))
                    .font(.subheadline)
                    .accessibilityIdentifier("practice-prompt")
                HStack(spacing: 8) {
                    Button("Switch turn", systemImage: "arrow.left.arrow.right") {
                        var updated = practiceSession
                        updated.switchTurn()
                        self.practiceSession = updated
                    }
                    .accessibilityIdentifier("practice-switch-turn")
                    Button("Next idea", systemImage: "arrow.right") {
                        var updated = practiceSession
                        updated.nextIdea()
                        self.practiceSession = updated
                    }
                    .accessibilityIdentifier("practice-next-idea")
                    Button("End practice", systemImage: "xmark") {
                        self.practiceSession = nil
                    }
                    .accessibilityIdentifier("practice-end")
                }
                .buttonStyle(.bordered)
                .font(.subheadline)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(store.settings.highContrast ? Color.white : Color.teal.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var boardFolderNavigationMenu: some View {
        Menu("Folders", systemImage: "folder") {
            ForEach(store.boardFoldersWithVisibleBoards, id: \.self) { folder in
                Menu(folder, systemImage: "folder") {
                    ForEach(store.visibleBoards(in: folder), id: \.self) { name in
                        Button(boardTabTitle(name)) {
                            navigator.goTo(name)
                            search = ""
                        }
                        .accessibilityLabel(name)
                    }
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Choose a folder, then a board")
        .accessibilityIdentifier("board-folder-navigation")
    }

    private var picturePanel: some View {
        let suggestedIDs = suggestedBoardWordIDs
        return VStack(spacing: 0) {
            if finderTarget != nil { finderBanner }
            if store.settings.progressiveVocabularyStage == .start
                || store.settings.progressiveVocabularyStage == .grow {
                progressiveVocabularyBanner
            }
            if focusActive {
                HStack(spacing: 8) {
                    Label("Focus words", systemImage: "scope")
                        .font(.subheadline.weight(.semibold))
                    Text("\(focusedWordIDs.count) selected")
                        .font(.subheadline)
                    Spacer()
                    Button("End focus") { focusActive = false }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("end-focus")
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(store.settings.highContrast ? Color.white : Color.purple.opacity(0.12))
            }
            if !currentBoardUsesTyping {
            HStack(spacing: 6) {
                ForEach(quickWords) { item in
                    Button(store.displayLabel(for: item).capitalized) { select(item) }
                        .buttonStyle(.borderedProminent)
                        .tint(store.settings.highContrast ? .black : .indigo)
                        .frame(maxWidth: .infinity)
                        .opacity(item.boardVisibility == .dimmed ? store.settings.dimmedButtonOpacity : 1)
                        .overlay(Capsule().strokeBorder(
                            focusedWordIDs.contains(item.id) ? (store.settings.highContrast ? .black : .purple) : .clear,
                            lineWidth: 4))
                        .overlay(Capsule().strokeBorder(
                            suggestedIDs.contains(item.id) ? (store.settings.highContrast ? .black : .teal) : .clear,
                            lineWidth: 3))
                        .overlay(Capsule().strokeBorder(
                            isScanHighlighted(.quickWord(item.id, store.displayLabel(for: item))) ? scanHighlightColor : .clear,
                            lineWidth: 4))
                        .accessibilityValue([
                            focusedWordIDs.contains(item.id) ? "Focus word" : nil,
                            suggestedIDs.contains(item.id) ? "Suggested next" : nil
                        ].compactMap { $0 }.joined(separator: ", "))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            }
            if !store.pinnedBoards.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(store.pinnedBoards, id: \.self) { name in
                            Button(boardTabTitle(name)) {
                                navigator.goTo(name)
                                search = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(navigator.currentBoard == name ? .indigo : .gray)
                            .accessibilityLabel(name)
                            .accessibilityAddTraits(navigator.currentBoard == name ? .isSelected : [])
                            .accessibilityIdentifier("pinned-board-\(name)")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("pinned-board-strip")
                .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.08))
            }
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            if !store.isBoardOnlyModeActive {
                                Button(focusActive ? "Focus active" : "Focus", systemImage: "scope") {
                                    showingFocus = true
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("open-focus")
                                .overlay(Capsule().strokeBorder(
                                    isScanHighlighted(.focusWords) ? scanHighlightColor : .clear,
                                    lineWidth: 4))
                                Button(store.settings.showBoardSuggestions ? "Hints on" : "Hints", systemImage: "sparkles") {
                                    store.settings.showBoardSuggestions.toggle()
                                }
                                .buttonStyle(.bordered)
                                .accessibilityHint("Outline likely next words without moving buttons")
                                .accessibilityIdentifier("board-suggestion-toggle")
                            }
                            if store.settings.recentPictureWordsEnabled {
                                Button("Recent", systemImage: "clock.arrow.circlepath") {
                                    navigator.goTo(recentBoardName)
                                    search = ""
                                }
                                .buttonStyle(.bordered)
                                .tint(navigator.currentBoard == recentBoardName ? .indigo : .primary)
                                .fontWeight(navigator.currentBoard == recentBoardName ? .bold : .regular)
                                .accessibilityAddTraits(navigator.currentBoard == recentBoardName ? .isSelected : [])
                                .accessibilityValue([
                                    focusBoardContains(recentBoardName) ? "Contains focus words" : nil,
                                    suggestedBoardContains(recentBoardName, ids: suggestedIDs) ? "Contains suggested words" : nil
                                ].compactMap { $0 }.joined(separator: ", "))
                                .overlay(Capsule().strokeBorder(
                                    isScanHighlighted(.board(recentBoardName)) ? scanHighlightColor : .clear,
                                    lineWidth: 4))
                                .accessibilityIdentifier("recent-board-tab")
                                .id("scan-board-\(recentBoardName)")
                            }
                            if !store.settings.scanEnabled && search.isEmpty {
                                Button(store.settings.groupedPictureBoard ? "Full grid" : "Large groups",
                                       systemImage: store.settings.groupedPictureBoard ? "square.grid.3x3" : "square.grid.2x2") {
                                    store.settings.groupedPictureBoard.toggle()
                                }
                                .buttonStyle(.bordered)
                                .accessibilityHint(store.settings.groupedPictureBoard
                                    ? "Show every picture button in the board grid"
                                    : "Choose a large group before choosing an enlarged picture button")
                                .accessibilityIdentifier("grouped-picture-board-toggle")
                                Button(store.settings.twoBoardsEnabled ? "One board" : "Two boards",
                                       systemImage: "rectangle.split.2x1") {
                                    store.settings.twoBoardsEnabled.toggle()
                                }
                                .buttonStyle(.bordered)
                                .accessibilityHint("Keep Core words available while browsing another board")
                                .accessibilityIdentifier("two-boards-toggle")
                            }
                            Button("Scenes", systemImage: "photo.on.rectangle") { showingScenes = true }
                                .buttonStyle(.bordered)
                                .accessibilityHint("Open photo scenes with words placed on them")
                                .accessibilityIdentifier("open-scenes")
                            Button("Bedside", systemImage: "bed.double.fill") {
                                showingBedside = true
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint("Speak urgent needs with large cards")
                            .accessibilityIdentifier("open-bedside")
                            if !navigator.history.isEmpty {
                                Button("Back", systemImage: "chevron.left") {
                                    navigator.back()
                                    search = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityHint("Return to the previous board")
                                .overlay(Capsule().strokeBorder(
                                    isScanHighlighted(.back) ? scanHighlightColor : .clear,
                                    lineWidth: 4))
                                .id("scan-board-back")
                            }
                            ForEach(store.visibleBoards, id: \.self) { name in
                                Button(boardTabTitle(name)) { navigator.goTo(name); search = "" }
                                    .buttonStyle(.bordered)
                                    .tint(navigator.currentBoard == name ? .indigo : .primary)
                                    .fontWeight(navigator.currentBoard == name ? .bold : .regular)
                                    .accessibilityLabel(name)
                                    .accessibilityAddTraits(navigator.currentBoard == name ? .isSelected : [])
                                    .accessibilityValue([
                                        finderTarget?.category == name && navigator.currentBoard != name
                                            ? "Word finder next board" : nil,
                                        focusBoardContains(name) ? "Contains focus words" : nil,
                                        suggestedBoardContains(name, ids: suggestedIDs) ? "Contains suggested words" : nil
                                    ].compactMap { $0 }.joined(separator: ", "))
                                    .overlay(Capsule().strokeBorder(
                                        finderTarget?.category == name && navigator.currentBoard != name
                                            ? (store.settings.highContrast ? .black : .pink) : .clear,
                                        lineWidth: 5))
                                    .overlay(Capsule().strokeBorder(
                                        focusBoardContains(name) ? (store.settings.highContrast ? .black : .purple) : .clear,
                                        lineWidth: 4))
                                    .overlay(Capsule().strokeBorder(
                                        suggestedBoardContains(name, ids: suggestedIDs) ? (store.settings.highContrast ? .black : .teal) : .clear,
                                        lineWidth: 3))
                                    .overlay(Capsule().strokeBorder(
                                        isScanHighlighted(.board(name)) ? scanHighlightColor : .clear,
                                        lineWidth: 4))
                                    .id("scan-board-\(name)")
                            }
                            Button("Favorites", systemImage: "star.fill") {
                                navigator.goTo("Favorites")
                                search = ""
                            }
                            .buttonStyle(.bordered)
                            .accessibilityValue([
                                focusBoardContains("Favorites") ? "Contains focus words" : nil,
                                suggestedBoardContains("Favorites", ids: suggestedIDs) ? "Contains suggested words" : nil
                            ].compactMap { $0 }.joined(separator: ", "))
                            .overlay(Capsule().strokeBorder(
                                focusBoardContains("Favorites") ? (store.settings.highContrast ? .black : .purple) : .clear,
                                lineWidth: 4))
                            .overlay(Capsule().strokeBorder(
                                suggestedBoardContains("Favorites", ids: suggestedIDs) ? (store.settings.highContrast ? .black : .teal) : .clear,
                                lineWidth: 3))
                            .overlay(Capsule().strokeBorder(
                                isScanHighlighted(.board("Favorites")) ? scanHighlightColor : .clear,
                                lineWidth: 4))
                            .id("scan-board-Favorites")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("board-tabs")
                    .onChange(of: highlightedTarget) { _, target in
                        if case .board(let name) = target {
                            proxy.scrollTo("scan-board-\(name)", anchor: .center)
                        } else if target == .back {
                            proxy.scrollTo("scan-board-back", anchor: .leading)
                        }
                    }
                    .onChange(of: finderTargetID) { _, _ in
                        if let target = finderTarget, target.category != "Core" {
                            proxy.scrollTo("scan-board-\(target.category)", anchor: .center)
                        }
                    }
                }
                Button("Lanyard cards", systemImage: "rectangle.stack") {
                    showingLanyard = true
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Lanyard cards")
                .accessibilityHint("Swipe through large cards and speak one without changing the message")
                .accessibilityIdentifier("open-lanyard-cards")
                .padding(.trailing, 8)
                if !store.boardFoldersWithVisibleBoards.isEmpty {
                    boardFolderNavigationMenu
                        .padding(.trailing, 8)
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Find a word")
            if let effectiveGridLayout {
                HStack(spacing: 12) {
                    Text("\(effectiveGridLayout.columns) \(effectiveGridLayout.columns == 1 ? "column" : "columns") × \(effectiveGridLayout.rows) \(effectiveGridLayout.rows == 1 ? "row" : "rows")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if boardPageCount > 1 {
                        Button("Previous page", systemImage: "chevron.left") {
                            boardPageIndex = max(0, currentBoardPage - 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(currentBoardPage == 0)
                        .overlay(Capsule().strokeBorder(
                            isScanHighlighted(.previousPage) ? scanHighlightColor : .clear, lineWidth: 4))
                        .accessibilityIdentifier("board-previous-page")
                        Text("Page \(currentBoardPage + 1) of \(boardPageCount)")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("board-page-count")
                        Button("Next page", systemImage: "chevron.right") {
                            boardPageIndex = min(boardPageCount - 1, currentBoardPage + 1)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(currentBoardPage + 1 >= boardPageCount)
                        .overlay(Capsule().strokeBorder(
                            isScanHighlighted(.nextPage) ? scanHighlightColor : .clear, lineWidth: 4))
                        .accessibilityIdentifier("board-next-page")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            boardArea(suggestedIDs: suggestedIDs)
        }
    }

    @ViewBuilder
    private func boardArea(suggestedIDs: Set<UUID>) -> some View {
        if showsPersistentCore {
            if horizontalSizeClass == .regular {
                GeometryReader { geometry in
                    let coreWidth = min(390, max(280, geometry.size.width * 0.38))
                    HStack(spacing: 0) {
                        persistentCoreGrid(width: coreWidth, suggestedIDs: suggestedIDs)
                            .frame(width: coreWidth)
                        Divider()
                        topicBoardScroll(suggestedIDs: suggestedIDs)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    persistentCoreStrip(suggestedIDs: suggestedIDs)
                    Divider()
                    topicBoardScroll(suggestedIDs: suggestedIDs)
                }
            }
        } else {
            topicBoardScroll(suggestedIDs: suggestedIDs)
        }
    }

    private func persistentCoreGrid(width: CGFloat, suggestedIDs: Set<UUID>) -> some View {
        let contentWidth = max(1, width - 24)
        let columns = max(1, Int((contentWidth + 10) / (coreTileSize.minimumWidth + 10)))
        let timeIDs = store.timeOfDayHighlightIDs(for: "Core", hour: timeHighlightHour)
        return VStack(alignment: .leading, spacing: 0) {
            Label("Core", systemImage: "pin.fill")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .accessibilityIdentifier("persistent-core-header")
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: columns), spacing: 10) {
                    ForEach(Array(persistentCoreSlots.enumerated()), id: \.offset) { entry in
                        if let item = entry.element {
                            persistentCoreTile(item, suggestedIDs: suggestedIDs, timeOfDayIDs: timeIDs)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: coreTileSize.minimumTileHeight + 16)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(12)
            }
            .accessibilityIdentifier("persistent-core-grid")
        }
        .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.06))
    }

    private func persistentCoreStrip(suggestedIDs: Set<UUID>) -> some View {
        let timeIDs = store.timeOfDayHighlightIDs(for: "Core", hour: timeHighlightHour)
        return VStack(alignment: .leading, spacing: 0) {
            Label("Core", systemImage: "pin.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .accessibilityIdentifier("persistent-core-header")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(persistentCoreSlots.enumerated()), id: \.offset) { entry in
                        if let item = entry.element {
                            persistentCoreTile(item, suggestedIDs: suggestedIDs, timeOfDayIDs: timeIDs)
                                .frame(width: coreTileSize.minimumWidth)
                        } else {
                            Color.clear
                                .frame(width: coreTileSize.minimumWidth,
                                       height: coreTileSize.minimumTileHeight + 16)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(height: coreTileSize.minimumTileHeight + 28)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("persistent-core-strip")
        }
        .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.06))
    }

    @ViewBuilder
    private func persistentCoreTile(_ item: CommunicationItem, suggestedIDs: Set<UUID>,
                                    timeOfDayIDs: Set<UUID>) -> some View {
        if item.boardVisibility == .hidden {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: coreTileSize.minimumTileHeight + 16)
                .accessibilityHidden(true)
        } else {
            CommunicationTile(item: item, size: coreTileSize,
                              highContrast: store.settings.highContrast,
                              grammarColorScheme: store.settings.grammarColorScheme,
                              isScanHighlighted: false,
                              isFocusHighlighted: focusedWordIDs.contains(item.id),
                              isSuggested: suggestedIDs.contains(item.id),
                              isRecentlyUsed: store.recentPictureHighlightIDs.contains(item.id),
                              isTimeOfDayHighlighted: timeOfDayIDs.contains(item.id),
                              isFinderHighlighted: finderTargetID == item.id,
                              holdDuration: store.settings.wordHoldDuration,
                              pointerDwellDuration: item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
                                  ? store.settings.pointerDwellDuration : 0,
                              contentOpacity: item.boardVisibility == .dimmed
                                  ? store.settings.dimmedButtonOpacity : 1,
                              displayLabel: store.displayLabel(for: item),
                              showsLabel: store.boardTileLabelsVisible(for: "Core")) {
                select(item)
            }
            .disabled(!item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive))
            .accessibilityIdentifier("persistent-core-\(item.label)")
        }
    }

    private func topicBoardScroll(suggestedIDs: Set<UUID>) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if usesGroupedPictureBoard {
                        groupedPictureGrid(suggestedIDs: suggestedIDs)
                    } else if effectiveGridLayout != nil {
                        ScrollView(.horizontal) {
                            boardGrid(suggestedIDs: suggestedIDs)
                                .frame(width: boardGridContentWidth)
                                .padding()
                        }
                    } else {
                        boardGrid(suggestedIDs: suggestedIDs).padding()
                    }
                    if store.items.contains(where: {
                        $0.arasaacPictogramID != nil &&
                        ($0.category == navigator.currentBoard ||
                         (showsPersistentCore && $0.category == "Core"))
                    }) {
                        Text(ARASAACPictogramService.attribution)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                    }
                }
            }
            .id(navigator.currentBoard)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                boardAvailableWidth = width
            }
            .onChange(of: highlightedTarget) { _, target in
                if case .word(let id, _) = target {
                    proxy.scrollTo("scan-word-\(id)", anchor: .center)
                } else if case .line(let axis, let index) = target {
                    let position = axis == .row ? index * boardColumnCount : index
                    if boardPageSlots.indices.contains(position), let item = boardPageSlots[position] {
                        proxy.scrollTo("scan-word-\(item.id)", anchor: .center)
                    }
                }
            }
            .onChange(of: finderTargetID) { _, _ in
                if let target = finderTarget, navigator.currentBoard == target.category {
                    scrollToFinderTarget(target, with: proxy)
                }
            }
            .onChange(of: navigator.currentBoard) { _, board in
                if let target = finderTarget, board == target.category {
                    scrollToFinderTarget(target, with: proxy)
                }
            }
            .onChange(of: boardPageIndex) { _, _ in
                if let target = finderTarget, navigator.currentBoard == target.category {
                    proxy.scrollTo("scan-word-\(target.id)", anchor: .center)
                }
            }
            .overlay {
                if navigator.currentBoard == recentBoardName && search.isEmpty && visibleItems.isEmpty {
                    ContentUnavailableView("No recent words yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Choose a picture word on any board to add it here."))
                } else if visibleItems.isEmpty && search.isEmpty && navigator.currentBoard != "Favorites" {
                    ContentUnavailableView {
                        Label("No buttons in \(navigator.currentBoard)", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Add a button to start using this board.")
                    } actions: {
                        if !store.isBoardOnlyModeActive {
                            Button("Add button") { showingAdd = true }
                        }
                    }
                } else if visibleItems.isEmpty && !search.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else if navigator.currentBoard == "Favorites" && store.items.allSatisfy({ !$0.isFavorite }) {
                    ContentUnavailableView("No favorites yet", systemImage: "star", description: Text("Use Customize → Edit words to add favorites."))
                }
            }
        }
    }

    private func scrollToFinderTarget(_ target: CommunicationItem, with proxy: ScrollViewProxy) {
        if usesGroupedPictureBoard && selectedBoardCluster == nil,
           let cluster = boardClusters.first(where: { $0.items.contains(where: { $0.id == target.id }) }) {
            proxy.scrollTo("board-group-\(cluster.id)", anchor: .center)
        } else {
            proxy.scrollTo("scan-word-\(target.id)", anchor: .center)
        }
    }

    private func groupedPictureGrid(suggestedIDs: Set<UUID>) -> some View {
        let clusters = boardClusters
        let timeIDs = store.timeOfDayHighlightIDs(for: navigator.currentBoard, hour: timeHighlightHour)
        return VStack(alignment: .leading, spacing: 12) {
            if let selectedBoardCluster,
               let cluster = clusters.first(where: { $0.id == selectedBoardCluster }) {
                HStack {
                    Button("All groups", systemImage: "chevron.left") {
                        self.selectedBoardCluster = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("all-picture-groups")
                    Text(cluster.rangeLabel)
                        .font(.headline)
                    Spacer(minLength: 0)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: horizontalSizeClass == .regular ? 3 : 2), spacing: 10) {
                    ForEach(Array(cluster.items.enumerated()), id: \.offset) { entry in
                        boardItemCell(entry.element, position: cluster.startIndex + entry.offset,
                                      suggestedIDs: suggestedIDs, timeOfDayIDs: timeIDs, enlarged: true)
                    }
                }
            } else {
                Text("Choose a group, then a picture button")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: horizontalSizeClass == .regular ? 3 : 2), spacing: 12) {
                    ForEach(clusters) { cluster in
                        pictureGroupButton(cluster, suggestedIDs: suggestedIDs)
                            .id("board-group-\(cluster.id)")
                    }
                }
            }
        }
        .padding()
    }

    private func pictureGroupButton(_ cluster: BoardWordCluster, suggestedIDs: Set<UUID>) -> some View {
        let available = cluster.items.filter {
            $0.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
        }
        let hasFocus = available.contains { focusedWordIDs.contains($0.id) }
        let hasSuggestion = available.contains { suggestedIDs.contains($0.id) }
        let hasFinderTarget = available.contains { finderTargetID == $0.id }
        return Button {
            selectedBoardCluster = cluster.id
        } label: {
            VStack(spacing: 8) {
                Text(cluster.rangeLabel)
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                    ForEach(available.prefix(6)) { item in
                        VStack(spacing: 1) {
                            if let data = item.imageData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 29)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Text(item.symbol)
                                    .font(.system(size: 25))
                            }
                            Text(store.displayLabel(for: item))
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    }
                }
                if available.count > 6 {
                    Text("+\(available.count - 6) more")
                        .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: horizontalSizeClass == .regular ? 182 : 160)
            .padding(10)
            .foregroundStyle(store.settings.highContrast ? .black : .primary)
            .background(store.settings.highContrast ? Color.white : Color(red: 0.87, green: 0.91, blue: 1),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                store.settings.highContrast ? .black : .indigo.opacity(0.35), lineWidth: 2))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                hasFocus ? (store.settings.highContrast ? .black : .purple) : .clear, lineWidth: 4))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                hasSuggestion ? (store.settings.highContrast ? .black : .teal) : .clear, lineWidth: 3))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                hasFinderTarget ? (store.settings.highContrast ? .black : .pink) : .clear, lineWidth: 5))
        }
        .buttonStyle(.plain)
        .disabled(available.isEmpty)
        .accessibilityLabel("\(cluster.rangeLabel): \(available.map(store.displayLabel(for:)).joined(separator: ", "))")
        .accessibilityHint("Open larger picture buttons")
        .accessibilityValue([
            hasFocus ? "Contains focus words" : nil,
            hasSuggestion ? "Contains suggested words" : nil,
            hasFinderTarget ? "Word finder next group" : nil
        ].compactMap { $0 }.joined(separator: ", "))
        .accessibilityIdentifier("picture-group-\(cluster.id)")
    }

    @ViewBuilder
    private func boardItemCell(_ item: CommunicationItem, position: Int,
                               suggestedIDs: Set<UUID>, timeOfDayIDs: Set<UUID>,
                               enlarged: Bool = false) -> some View {
        if item.boardVisibility == .hidden {
            hiddenBoardSlot(position: position, enlarged: enlarged)
                .id("scan-word-\(item.id)")
        } else if store.settings.wordHoldDuration > 0 || store.isBoardOnlyModeActive {
            wordTile(item, position: position, suggestedIDs: suggestedIDs,
                     timeOfDayIDs: timeOfDayIDs, enlarged: enlarged)
                .id("scan-word-\(item.id)")
        } else {
            wordTile(item, position: position, suggestedIDs: suggestedIDs,
                     timeOfDayIDs: timeOfDayIDs, enlarged: enlarged)
                .contextMenu {
                    Button(item.isFavorite ? "Remove favorite" : "Add favorite",
                           systemImage: item.isFavorite ? "star.slash" : "star") {
                        store.toggleFavorite(item)
                    }
                    Button("Edit", systemImage: "pencil") { editingItem = item }
                }
                .id("scan-word-\(item.id)")
        }
    }

    private var currentTypedWordFormContext: TypedWordForms.Context? {
        guard let cursorOffset = typedCursorOffset else { return nil }
        return TypedWordForms.context(in: store.typedMessage, cursorOffset: cursorOffset,
                                      language: store.settings.communicationLanguage)
    }

    private var typedCursorOffset: Int? {
        let offset = store.typedCursorOffset ?? store.typedMessage.count
        return (0...store.typedMessage.count).contains(offset) ? offset : nil
    }

    private var gridTypedMessageDisplay: String {
        let message = store.typedMessage
        guard !message.isEmpty else { return "Tap keys to write a message" }
        guard let offset = typedCursorOffset, offset < message.count else { return message }
        return String(message.prefix(offset)) + "│" + String(message.dropFirst(offset))
    }

    private var typedSentenceSuggestions: [String] {
        guard typedCursorOffset == store.typedMessage.count else { return [] }
        return SentencePrediction.suggestions(for: store.typedMessage, phrases: store.phrases,
                                              quickResponses: store.settings.quickResponses,
                                              history: store.settings.saveHistory ? store.history : [],
                                              learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
                                              language: store.settings.communicationLanguage)
    }

    private func setTypedMessageAndCaret(_ text: String) {
        store.typedMessage = text
        store.typedCursorOffset = text.count
    }

    private var typingPanel: some View {
        VStack(spacing: 0) {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            QuickResponseBar()
            HStack {
                Text("Type a message")
                    .font(.headline)
                Spacer()
                speechVolumeButton
                Button("Notes", systemImage: "note.text") { showingNotes = true }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("open-notes")
                if !store.isBoardOnlyModeActive {
                    Button(store.activeConversationName, systemImage: "bubble.left.and.bubble.right") {
                        showingConversations = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("open-conversations")
                }
            }
            MessageTextEditor(text: $store.typedMessage, cursorOffset: $store.typedCursorOffset) {
                previous, current in
                store.previewTypedSpeech(previous: previous, current: current)
            }
                .id(store.activeConversationID)
                .frame(minHeight: 180, maxHeight: 300)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.gray.opacity(0.3)))
            if let highlight = store.speechHighlight, highlight.source == .typed {
                SpeechFollowAlongView(state: highlight)
            }
            HStack {
                Button("ABC keyboard", systemImage: "character.cursor.ibeam") {
                    showingAlphabetKeyboard = true
                }
                .accessibilityIdentifier("open-alphabet-keyboard")
                Button("Word forms", systemImage: "textformat") {
                    typedWordFormContext = currentTypedWordFormContext
                }
                .disabled(currentTypedWordFormContext == nil)
                .accessibilityHint("Change the supported word at the cursor")
                .accessibilityIdentifier("typed-word-forms")
                Button("Communication repair", systemImage: "arrow.uturn.backward") {
                    showingCommunicationRepair = true
                }
                .labelStyle(.iconOnly)
                .accessibilityHint("Speak a phrase without changing your message")
                .accessibilityIdentifier("open-communication-repair")
                Spacer()
                if !store.isBoardOnlyModeActive {
                    Menu {
                        Toggle("Characters", isOn: $store.settings.speakTypedCharacters)
                        Toggle("Words", isOn: $store.settings.speakTypedWords)
                        Toggle("Sentences", isOn: $store.settings.speakTypedSentences)
                    } label: {
                        Label("Typing speech", systemImage: "waveform")
                    }
                    .accessibilityIdentifier("typing-speech-options")
                }
            }
            let shortcuts = PhraseShortcut.matches(store.typedMessage, phrases: store.phrases)
            if !shortcuts.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(shortcuts) { phrase in
                            Button {
                                if PhraseTemplate.fields(in: phrase.text).isEmpty {
                                    setTypedMessageAndCaret(PhraseShortcut.expanding(store.typedMessage, with: phrase.text))
                                } else {
                                    fillingShortcutPhrase = phrase
                                }
                            } label: {
                                Label("\(phrase.shortcut ?? "") → \(phrase.text)", systemImage: "text.badge.plus")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("shortcut-\(phrase.shortcut ?? "")")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityLabel("Phrase shortcuts")
            }
            let sentenceSuggestions = typedSentenceSuggestions
            let suggestions = WordPrediction.suggestions(
                for: store.typedMessage, items: store.localizedItems(excludingPredictionKeys: true), phrases: store.phrases,
                history: store.settings.saveHistory ? store.history : [],
                learned: store.settings.learnPrediction ? store.learnedPrediction : nil,
                language: store.settings.communicationLanguage)
            let trailingEmoji = typedCursorOffset == store.typedMessage.count
                ? EmojiWordPrediction.trailingEmoji(in: store.typedMessage) : nil
            let emojiWords = trailingEmoji == nil ? [] : EmojiWordPrediction.suggestions(
                for: store.typedMessage, language: store.settings.communicationLanguage)
            ScrollView(.horizontal) {
                HStack {
                    if let trailingEmoji {
                        Button("Keep \(trailingEmoji)") {
                            setTypedMessageAndCaret(EmojiWordPrediction.keepingTrailingEmoji(
                                in: store.typedMessage))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("emoji-keep")
                        ForEach(emojiWords, id: \.self) { word in
                            Button(word) {
                                setTypedMessageAndCaret(EmojiWordPrediction.replacingTrailingEmoji(
                                    in: store.typedMessage, with: word))
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Replace \(trailingEmoji) with \(word)")
                            .accessibilityIdentifier("emoji-word-\(word.lowercased().replacingOccurrences(of: " ", with: "-"))")
                        }
                    } else if suggestions.isEmpty && sentenceSuggestions.isEmpty {
                        Text("Suggestions appear as you type")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if trailingEmoji == nil {
                        ForEach(Array(sentenceSuggestions.enumerated()), id: \.offset) { index, sentence in
                            Button {
                                if let completed = SentencePrediction.completing(store.typedMessage,
                                                                                 with: sentence) {
                                    setTypedMessageAndCaret(completed)
                                }
                            } label: {
                                Label(sentence, systemImage: "text.quote")
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 220, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Complete sentence: \(sentence)")
                            .accessibilityIdentifier("sentence-suggestion-\(index)")
                        }
                        ForEach(suggestions, id: \.self) { word in
                            Button(word) {
                                setTypedMessageAndCaret(WordPrediction.completing(store.typedMessage,
                                                                                 with: word))
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint(store.typedMessage.last?.isWhitespace == true
                                ? "Add this word to the message" : "Complete the word")
                            .accessibilityIdentifier(store.typedMessage.last?.isWhitespace == true
                                ? "next-word-suggestion-\(word.lowercased())"
                                : "word-suggestion-\(word.lowercased())")
                        }
                    }
                }
            }
            .frame(height: 60)
            .scrollIndicators(.hidden)
            .accessibilityLabel(trailingEmoji != nil ? "Emoji word suggestions" : (suggestions.isEmpty
                                ? (sentenceSuggestions.isEmpty ? "Text suggestions" : "Sentence suggestions")
                                : (store.typedMessage.last?.isWhitespace == true
                                   ? "Next word suggestions" : "Word suggestions")))
            HStack {
                Button("Speak text", systemImage: "speaker.wave.2.fill") {
                    store.speak(store.typedMessage, saveToHistory: true, followAlong: .typed)
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer(minLength: 0)
                Button("Clear", systemImage: "xmark") {
                    store.stopSpeaking()
                    setTypedMessageAndCaret("")
                }
                    .disabled(store.typedMessage.isEmpty)
                Menu {
                    Button("Full-screen typing", systemImage: "arrow.up.left.and.arrow.down.right") {
                        showingExpandedTyping = true
                    }
                    .accessibilityIdentifier("open-expanded-typing")
                    if !store.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Divider()
                        if !store.isBoardOnlyModeActive {
                            Button("Save phrase", systemImage: "star") { store.addPhrase(store.typedMessage) }
                            Button("Save as button", systemImage: "plus.square") {
                                messageButtonDraft = MessageButtonDraft(
                                    text: store.typedMessage,
                                    category: navigator.currentBoard == "Favorites" ? "Core" : navigator.currentBoard,
                                    language: store.settings.communicationLanguage)
                            }
                            Button("Store on existing button", systemImage: "square.and.pencil") {
                                targetButtonDraft = MessageButtonDraft(
                                    text: store.typedMessage,
                                    category: navigator.currentBoard == "Favorites" ? "Core" : navigator.currentBoard,
                                    language: store.settings.communicationLanguage)
                            }
                        }
                        Button("Show large message", systemImage: "rectangle.expand.vertical") { showingTypedMessage = true }
                        ShareLink(item: store.typedMessage) { Label("Share", systemImage: "square.and.arrow.up") }
                        if !nearby.connectedPeers.isEmpty {
                            Button("Send nearby", systemImage: "bubble.left.and.bubble.right") {
                                sendNearby(store.typedMessage)
                            }
                        }
                        Button("Share audio", systemImage: "waveform") {
                            prepareAudioShare(store.typedMessage, isPictureMessage: false)
                        }
                        .disabled(isPreparingAudioShare)
                        .accessibilityIdentifier("share-typed-audio")
                    }
                    Button("Nearby chat", systemImage: "bubble.left.and.bubble.right") {
                        showingNearbyChat = true
                    }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        MessagePlaybackControl(source: .typed)
        }
    }

    private func prepareAudioShare(_ message: String, isPictureMessage: Bool) {
        guard !isPreparingAudioShare else { return }
        isPreparingAudioShare = true
        Task {
            defer { isPreparingAudioShare = false }
            do {
                let url = try await store.exportMessageAudio(message, isPictureMessage: isPictureMessage)
                audioSharePayload = AudioSharePayload(url: url)
            } catch {
                audioShareError = error.localizedDescription
                showingAudioShareError = true
            }
        }
    }

    private func sendNearby(_ text: String, pictureTokens: [PictureMessageToken] = []) {
        do { try nearby.send(text, pictureTokens: pictureTokens) }
        catch {
            nearbySendError = error.localizedDescription
            showingNearbySendError = true
        }
    }

    private func isScanHighlighted(_ target: ScanTarget) -> Bool {
        store.settings.scanEnabled && highlightedTarget == target
    }

    private func isScanLineHighlighted(at position: Int) -> Bool {
        guard store.settings.scanEnabled,
              case .line(let axis, let index) = highlightedTarget else { return false }
        return axis == .row
            ? position / max(1, boardColumnCount) == index
            : position % max(1, boardColumnCount) == index
    }

    private func wordTile(_ item: CommunicationItem, position: Int, suggestedIDs: Set<UUID>,
                          timeOfDayIDs: Set<UUID>, enlarged: Bool = false) -> some View {
        let unavailablePrediction = item.effectiveAction == .completeTypedPrediction
            && store.typedPrediction(for: item) == nil
        return CommunicationTile(item: item, size: enlarged ? .large : effectiveTileSize,
                          highContrast: store.settings.highContrast,
                          grammarColorScheme: store.settings.grammarColorScheme,
                          isScanHighlighted: isScanHighlighted(.word(item.id, store.displayLabel(for: item)))
                              || isScanLineHighlighted(at: position),
                          isFocusHighlighted: focusedWordIDs.contains(item.id),
                          isSuggested: suggestedIDs.contains(item.id),
                          isRecentlyUsed: search.isEmpty && store.categories.contains(navigator.currentBoard)
                              && store.recentPictureHighlightIDs.contains(item.id),
                          isTimeOfDayHighlighted: search.isEmpty && timeOfDayIDs.contains(item.id),
                          isFinderHighlighted: finderTargetID == item.id,
                          holdDuration: store.settings.wordHoldDuration,
                          pointerDwellDuration: item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive)
                              && !unavailablePrediction
                              ? store.settings.pointerDwellDuration : 0,
                          contentOpacity: unavailablePrediction ? 0.42 : item.boardVisibility == .dimmed
                              ? store.settings.dimmedButtonOpacity : 1,
                          displayLabel: store.displayLabel(for: item),
                          showsLabel: !search.isEmpty || store.boardTileLabelsVisible(for: navigator.currentBoard)) {
                select(item)
            }
            .disabled(unavailablePrediction
                || !item.isBoardSelectable(dimmedButtonsActive: store.settings.dimmedButtonsActive))
            .accessibilityIdentifier(item.effectiveAction.isTypingAction
                ? "board-key-\(item.label)" : "")
    }

    private func hiddenBoardSlot(position: Int, enlarged: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.clear)
            .frame(maxWidth: .infinity, minHeight: (enlarged ? TileSize.large : effectiveTileSize).minimumTileHeight + 16)
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(
                isScanLineHighlighted(at: position) ? scanHighlightColor : .clear, lineWidth: 5))
            .accessibilityHidden(true)
    }

    private func scanningItem(_ item: CommunicationItem) -> CommunicationItem {
        var copy = item
        copy.label = store.displayLabel(for: item)
        if item.effectiveAction == .completeTypedPrediction,
           store.typedPrediction(for: item) == nil {
            copy.visibility = .hidden
        }
        return copy
    }

    private func switchBoardLanguage(to language: String) {
        guard store.settings.communicationLanguage != language else { return }
        store.settings.communicationLanguage = language
        store.settings.voiceIdentifier = ""
        store.settings.scanCueVoiceIdentifier = ""
        pendingItem = nil
        pendingScanWordID = nil
        scanner.enter(.words)
    }

    private func selectHighlighted() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35 else { return }
        lastScanActivation = now
        guard let target = highlightedTarget else { return }
        switch target {
        case .chooseBoards:
            scanner.enter(.boards)
        case .messageControls:
            scanner.enter(.message)
        case .returnToWords:
            scanner.enter(.words)
        case .returnToLines:
            scanner.enter(.words)
        case .line(_, let line):
            scanner.enterLine(line)
        case .quickWord(let id, _), .word(let id, _):
            if let item = store.items.first(where: { $0.id == id }) {
                let wasLine = scanner.group == .line
                select(item, fromScanner: true)
                if wasLine && pendingScanWordID == nil { scanner.enter(.words) }
            }
        case .board(let name):
            navigator.goTo(name)
            search = ""
            scanner.enter(.words)
        case .back:
            navigator.back()
            search = ""
            scanner.enter(.words)
        case .previousPage:
            boardPageIndex = max(0, currentBoardPage - 1)
            scanner.enter(.words)
        case .nextPage:
            boardPageIndex = min(boardPageCount - 1, currentBoardPage + 1)
            scanner.enter(.words)
        case .speak:
            store.speakMessage()
        case .attention:
            showingAttention = true
        case .conversations:
            if !store.isBoardOnlyModeActive { showingConversations = true }
        case .focusWords:
            if !store.isBoardOnlyModeActive { showingFocus = true }
        case .undo:
            store.removeLast()
        case .clear:
            store.clearMessage()
        }
    }

    private func select(_ item: CommunicationItem, fromScanner: Bool = false) {
        if usesGroupedPictureBoard && !fromScanner { selectedBoardCluster = nil }
        if finderTargetID == item.id { finderTargetID = nil }
        if let destination = item.destinationBoard {
            if navigator.open(destination, behavior: item.linkBehavior ?? .navigate,
                              availableBoards: store.categories) {
                search = ""
                scanner.enter(.words)
            }
            return
        }
        if item.effectiveAction.allowsPhraseOptions && !(item.phraseOptions ?? []).isEmpty {
            phraseItem = item
            pendingScanWordID = nil
            return
        }
        if store.settings.confirmSelection {
            if fromScanner {
                if pendingScanWordID == item.id {
                    commitSelection(item, fromScanner: true)
                    pendingScanWordID = nil
                } else {
                    pendingScanWordID = item.id
                }
            } else {
                pendingItem = item
            }
        } else {
            commitSelection(item, fromScanner: fromScanner)
        }
    }

    private func commitSelection(_ item: CommunicationItem, fromScanner: Bool = false) {
        if !fromScanner && !repeatTapFilter.allows(item.id, interval: store.settings.repeatFilterInterval) {
            return
        }
        if item.effectiveAction == .playVideo {
            guard item.hasValidVideoMedia, item.videoData != nil else { return }
            store.stopSpeaking()
            playingVideoItem = item
            return
        }
        if item.effectiveAction == .openWebPage {
            guard ButtonWebLink.url(item.webURL) != nil else { return }
            store.stopSpeaking()
            webPageItem = item
            return
        }
        if item.effectiveAction == .openKeyboard {
            isTyping = true
            return
        }
        if item.effectiveAction == .openScene {
            if let id = item.destinationSceneID,
               let scene = store.sceneBoards.first(where: { $0.id == id }) {
                selectedScene = scene
            } else {
                var fallback = item
                fallback.action = nil
                fallback.destinationSceneID = nil
                store.select(fallback)
                navigator.selectWord()
            }
            return
        }
        store.select(item)
        switch item.effectiveAction {
        case .backBoard:
            navigator.back()
            search = ""
            scanner.enter(.words)
        case .homeBoard:
            navigator.goTo(store.homeBoard)
            search = ""
            scanner.enter(.words)
        default:
            if item.effectiveAction.usesOwnMessage { navigator.selectWord() }
        }
    }
}

private struct MessageButtonTargetPicker: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedItem: CommunicationItem?
    @State private var showingConfirmation = false

    let message: String
    let language: String

    private var matchingItems: [CommunicationItem] {
        store.items.filter { item in
            item.effectiveAction.usesOwnMessage &&
                (search.isEmpty || item.label.localizedCaseInsensitiveContains(search)
                    || item.category.localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose a speaking button. Its label and picture will stay the same.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Find a button", text: $search)
                        .accessibilityIdentifier("store-message-search")
                }
                Section("Speaking buttons") {
                    ForEach(matchingItems) { item in
                        Button {
                            selectedItem = item
                            showingConfirmation = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.symbol).font(.title2).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.displayLabel(for: item)).font(.headline)
                                    Text(item.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.audioData != nil { Image(systemName: "mic.fill") }
                            }
                        }
                        .accessibilityLabel("Store on \(store.displayLabel(for: item))")
                        .accessibilityIdentifier("store-message-target-\(item.id.uuidString)")
                    }
                }
            }
            .navigationTitle("Store on a button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Replace button message?", isPresented: $showingConfirmation, presenting: selectedItem) { item in
                Button("Store message") {
                    if store.storeMessageOnButton(message, itemID: item.id, language: language) {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { selectedItem = nil }
            } message: { item in
                let current = language == "es"
                    ? store.translation(for: item, language: "es")?.message ?? item.message : item.message
                let extra = item.audioData != nil || !(item.phraseOptions ?? []).isEmpty
                    ? " Its recording or phrase choices will be removed." : ""
                Text("\(item.label) currently says: \(current)\nNew message: \(message).\(extra)")
            }
        }
    }
}
