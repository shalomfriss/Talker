import XCTest
@testable import OpenVoice

final class BoardScannerTests: XCTestCase {
    func testPointerDwellNeedsStableHoverAndFiresOnlyOnceUntilLeave() {
        var dwell = PointerDwellState()
        XCTAssertTrue(dwell.moved(to: CGPoint(x: 20, y: 20)))
        let first = dwell.generation
        XCTAssertFalse(dwell.moved(to: CGPoint(x: 28, y: 26)))
        XCTAssertEqual(dwell.generation, first)
        XCTAssertTrue(dwell.moved(to: CGPoint(x: 50, y: 20)))
        XCTAssertFalse(dwell.activate(generation: first))
        XCTAssertTrue(dwell.activate(generation: dwell.generation))
        XCTAssertFalse(dwell.activate(generation: dwell.generation))
        XCTAssertFalse(dwell.moved(to: CGPoint(x: 80, y: 20)))
        dwell.leave()
        XCTAssertFalse(dwell.isWaiting)
        XCTAssertTrue(dwell.moved(to: CGPoint(x: 80, y: 20)))
        XCTAssertTrue(dwell.activate(generation: dwell.generation))
    }

    func testPointerDwellSettingDefaultsOffAndBoundsImportedValue() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.pointerDwellDuration, 0)
        let imported = try JSONDecoder().decode(AppSettings.self,
            from: Data("{\"pointerDwellDuration\":99}".utf8))
        XCTAssertEqual(imported.pointerDwellDuration, 3)
    }

    @MainActor
    func testPointerDwellSettingStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("dwell.json")
        let store = CommunicationStore(storageURL: file)
        let original = store.activeProfileID
        store.settings.pointerDwellDuration = 1.2
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.pointerDwellDuration, 1.2)
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertEqual(store.settings.pointerDwellDuration, 0)
        XCTAssertTrue(store.switchProfile(to: original))
        XCTAssertEqual(store.settings.pointerDwellDuration, 1.2)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.pointerDwellDuration, 1.2)
    }

    func testOneSwitchSequenceCanReachWordsBoardsAndMessageActions() {
        let quick = StarterVocabulary.items.filter { ["yes", "no", "help", "break"].contains($0.label) }
        let board = StarterVocabulary.items.filter { $0.category == "Core" }
        var scanner = BoardScanner()

        let words = scanner.targets(quickWords: quick, boardItems: board,
                                    boards: ["Core", "Needs"], hasBack: false, hasMessage: false)
        XCTAssertEqual(words.first, .chooseBoards)
        XCTAssertEqual(words.dropFirst().first, .messageControls)
        XCTAssertTrue(words.contains { if case .quickWord(_, "help") = $0 { return true }; return false })
        XCTAssertTrue(words.contains { if case .word(_, "want") = $0 { return true }; return false })
        for _ in 0..<words.count { scanner.advance(targetCount: words.count) }
        XCTAssertEqual(scanner.highlighted(in: words), .chooseBoards)

        scanner.enter(.boards)
        let boards = scanner.targets(quickWords: quick, boardItems: board,
                                     boards: ["Core", "Needs"], hasBack: true, hasMessage: false)
        XCTAssertEqual(boards, [.returnToWords, .back, .board("Core"), .board("Needs"), .board("Favorites")])

        scanner.enter(.message)
        let actions = scanner.targets(quickWords: quick, boardItems: board,
                                      boards: [], hasBack: false, hasMessage: true)
        XCTAssertEqual(actions, [.returnToWords, .attention, .conversations, .focusWords, .speak, .undo, .clear])
        scanner.advance(targetCount: actions.count)
        XCTAssertEqual(scanner.highlighted(in: actions), .attention)
        scanner.advance(targetCount: actions.count)
        XCTAssertEqual(scanner.highlighted(in: actions), .conversations)
        scanner.advance(targetCount: actions.count)
        XCTAssertEqual(scanner.highlighted(in: actions), .focusWords)
        scanner.advance(targetCount: actions.count)
        XCTAssertEqual(scanner.highlighted(in: actions), .speak)
        let emptyActions = scanner.targets(quickWords: quick, boardItems: board,
                                           boards: [], hasBack: false, hasMessage: false)
        XCTAssertEqual(emptyActions, [.returnToWords, .attention, .conversations, .focusWords])
        scanner.reconcile(targetCount: 1)
        XCTAssertEqual(scanner.highlighted(in: [.returnToWords]), .returnToWords)
    }

    func testRowAndColumnScanningUsesGridPositions() {
        let items = Array(StarterVocabulary.items.filter { $0.category == "Core" }.prefix(8))
        var scanner = BoardScanner()
        XCTAssertEqual(BoardScanner.columnCount(availableWidth: 393, minimumTileWidth: 108), 3)
        XCTAssertEqual(BoardScanner.columnCount(availableWidth: 834, minimumTileWidth: 108), 6)

        let rows = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                   hasBack: false, hasMessage: false,
                                   pattern: .rowColumn, columns: 3)
        XCTAssertEqual(Array(rows.suffix(3)), [.line(.row, 0), .line(.row, 1), .line(.row, 2)])
        scanner.enterLine(1)
        let rowButtons = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                         hasBack: false, hasMessage: false,
                                         pattern: .rowColumn, columns: 3)
        XCTAssertEqual(rowButtons, [.returnToLines] + items[3...5].map { .word($0.id, $0.label) })

        scanner.enter(.words)
        let columns = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                      hasBack: false, hasMessage: false,
                                      pattern: .columnRow, columns: 3)
        XCTAssertEqual(Array(columns.suffix(3)), [.line(.column, 0), .line(.column, 1), .line(.column, 2)])
        scanner.enterLine(1)
        let columnButtons = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                            hasBack: false, hasMessage: false,
                                            pattern: .columnRow, columns: 3)
        XCTAssertEqual(columnButtons, [.returnToLines] + [items[1], items[4], items[7]].map {
            .word($0.id, $0.label)
        })
    }

    func testScanningSkipsEmptyGridPositionsWithoutShiftingRows() {
        let items = Array(StarterVocabulary.items.filter { $0.category == "Core" }.prefix(3))
        var scanner = BoardScanner()
        let rows = scanner.targets(quickWords: [], boardItems: items, emptyPositions: [1],
                                   boards: [], hasBack: false, hasMessage: false,
                                   pattern: .rowColumn, columns: 2)
        XCTAssertEqual(Array(rows.suffix(2)), [.line(.row, 0), .line(.row, 1)])
        scanner.enterLine(0)
        XCTAssertEqual(scanner.targets(quickWords: [], boardItems: items, emptyPositions: [1],
                                       boards: [], hasBack: false, hasMessage: false,
                                       pattern: .rowColumn, columns: 2),
                       [.returnToLines, .word(items[0].id, items[0].label)])
        scanner.enterLine(1)
        XCTAssertEqual(scanner.targets(quickWords: [], boardItems: items, emptyPositions: [1],
                                       boards: [], hasBack: false, hasMessage: false,
                                       pattern: .rowColumn, columns: 2),
                       [.returnToLines, .word(items[1].id, items[1].label),
                        .word(items[2].id, items[2].label)])
    }

    func testScannerIncludesOnlyAvailableFixedGridPageControls() {
        let items = Array(StarterVocabulary.items.filter { $0.category == "Core" }.prefix(4))
        let scanner = BoardScanner()
        let first = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                    hasBack: false, hasMessage: false, pattern: .rowColumn,
                                    columns: 2, hasNextPage: true)
        XCTAssertEqual(Array(first.prefix(3)), [.chooseBoards, .messageControls, .nextPage])
        XCTAssertEqual(Array(first.suffix(2)), [.line(.row, 0), .line(.row, 1)])
        let middle = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                     hasBack: false, hasMessage: false, pattern: .sequential,
                                     columns: 2, hasPreviousPage: true, hasNextPage: true)
        XCTAssertEqual(Array(middle.prefix(4)), [.chooseBoards, .messageControls,
                                                 .previousPage, .nextPage])
        XCTAssertEqual(ScanCue.forTarget(.nextPage, language: "es").text, "Página siguiente")
    }

    func testSpokenScanCuesUseTheButtonLabelAndSelectedLanguage() {
        let id = UUID()
        XCTAssertEqual(ScanCue.forTarget(.word(id, "agua"), language: "es"),
                       ScanCue(text: "agua", language: "es"))
        XCTAssertEqual(ScanCue.forTarget(.quickWord(id, "sí"), language: "es"),
                       ScanCue(text: "sí", language: "es"))
        XCTAssertEqual(ScanCue.forTarget(.line(.row, 1), language: "es"),
                       ScanCue(text: "Fila 2", language: "es"))
        XCTAssertEqual(ScanCue.forTarget(.line(.column, 2), language: "en"),
                       ScanCue(text: "Column 3", language: "en"))
        XCTAssertEqual(ScanCue.forTarget(.speak, language: "es"),
                       ScanCue(text: "Decir mensaje", language: "es"))
        XCTAssertEqual(ScanCue.forConfirmation("agua", language: "es"),
                       ScanCue(text: "Selecciona de nuevo para agregar agua", language: "es"))
    }

    func testHiddenAndInactiveDimmedButtonsKeepGridPositionsButLeaveScanTargets() {
        var items = Array(StarterVocabulary.items.filter { $0.category == "Core" }.prefix(7))
        for position in 0..<3 { items[position].visibility = .hidden }
        items[3].visibility = .dimmed
        var scanner = BoardScanner()

        let sequential = scanner.targets(quickWords: [items[0], items[3]], boardItems: items,
                                         boards: [], hasBack: false, hasMessage: false,
                                         dimmedButtonsActive: false)
        XCTAssertFalse(sequential.contains { $0 == .word(items[0].id, items[0].label) })
        XCTAssertFalse(sequential.contains { $0 == .word(items[3].id, items[3].label) })
        XCTAssertFalse(sequential.contains { $0 == .quickWord(items[3].id, items[3].label) })

        let rows = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                   hasBack: false, hasMessage: false,
                                   pattern: .rowColumn, columns: 3, dimmedButtonsActive: false)
        XCTAssertEqual(Array(rows.suffix(2)), [.line(.row, 1), .line(.row, 2)])
        scanner.enterLine(1)
        let rowButtons = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                         hasBack: false, hasMessage: false,
                                         pattern: .rowColumn, columns: 3, dimmedButtonsActive: false)
        XCTAssertEqual(rowButtons, [.returnToLines] + items[4...5].map { .word($0.id, $0.label) })

        scanner.enter(.words)
        let activeRows = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                         hasBack: false, hasMessage: false,
                                         pattern: .rowColumn, columns: 3, dimmedButtonsActive: true)
        XCTAssertTrue(activeRows.contains(.line(.row, 1)))
        scanner.enterLine(1)
        let activeRowButtons = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                               hasBack: false, hasMessage: false,
                                               pattern: .rowColumn, columns: 3, dimmedButtonsActive: true)
        XCTAssertTrue(activeRowButtons.contains(.word(items[3].id, items[3].label)))

        scanner.enter(.words)
        let columns = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                      hasBack: false, hasMessage: false,
                                      pattern: .columnRow, columns: 3, dimmedButtonsActive: false)
        XCTAssertTrue(columns.contains(.line(.column, 0)))
        scanner.enterLine(0)
        let columnButtons = scanner.targets(quickWords: [], boardItems: items, boards: [],
                                            hasBack: false, hasMessage: false,
                                            pattern: .columnRow, columns: 3, dimmedButtonsActive: false)
        XCTAssertEqual(columnButtons, [.returnToLines, .word(items[6].id, items[6].label)])
    }
}
