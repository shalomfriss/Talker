import XCTest
@testable import OpenVoice

final class SpellingBoardTests: XCTestCase {
    @MainActor
    func testSpellingBoardTypesIntoConversationWithoutChangingPictureDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let picture = try XCTUnwrap(store.items.first { $0.category == "Core" && $0.effectiveAction == .addToMessage })
        store.select(picture)
        let pictureMessage = store.composedMessage
        let board = try XCTUnwrap(store.addSpellingBoard())
        let keys = store.items.filter { $0.category == board }
        XCTAssertEqual(keys.filter { $0.effectiveAction == .typeText }.count, 27)
        XCTAssertNil(store.gridLayout(for: board))
        XCTAssertEqual(keys.prefix(2).map(\.effectiveAction), [.typeSpace, .deleteTypedCharacter])

        func key(_ label: String) throws -> CommunicationItem {
            try XCTUnwrap(keys.first { $0.label == label })
        }
        store.select(try key("A"))
        store.select(try key("B"))
        store.select(try key("Space"))
        store.select(try key("B"))
        XCTAssertEqual(store.typedMessage, "Ab b")
        store.select(try key("Delete"))
        XCTAssertEqual(store.typedMessage, "Ab ")
        store.select(try key("Speak"))
        XCTAssertEqual(store.typedMessage, "Ab ")
        XCTAssertEqual(store.composedMessage, pictureMessage)
        store.flushConversationDraft()
        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(reloaded.typedMessage, "Ab ")
        XCTAssertEqual(reloaded.composedMessage, pictureMessage)
        XCTAssertEqual(reloaded.items.filter { $0.category == board }.count, keys.count)
        let backup = try store.backupData()
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(backup)
        XCTAssertEqual(imported.typedMessage, "Ab ")
        XCTAssertEqual(imported.items.filter { $0.category == board }.map(\.effectiveAction),
                       keys.map(\.effectiveAction))
        store.select(try key("Clear"))
        XCTAssertTrue(store.typedMessage.isEmpty)
        XCTAssertEqual(store.composedMessage, pictureMessage)
        XCTAssertNotNil(store.addSpellingBoard())
    }

    func testSpellingActionsRoundTripThroughOpenBoardFile() throws {
        let items = SpellingBoardFactory.items(board: "Spelling")
        let data = try OpenBoardFormat.exportBoard(name: "Spelling", items: items, language: "en",
                                                   layout: BoardGridLayout(columns: 5, rows: 7))
        let imported = try OpenBoardFormat.importData(data, fileExtension: "obf")
        XCTAssertEqual(imported.items.map(\.effectiveAction), items.map(\.effectiveAction))
        XCTAssertEqual(imported.items.first { $0.label == "Ñ" }?.message, "ñ")
        XCTAssertEqual(imported.items.filter { $0.effectiveAction == .completeTypedPrediction }
            .map(\.message), ["0", "1", "2"])
    }

    @MainActor
    func testQwertyBoardHasLettersNumbersPunctuationAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("qwerty.json")
        let store = CommunicationStore(storageURL: file)
        let board = try XCTUnwrap(store.addSpellingBoard(layout: .qwerty))
        let keys = store.items.filter { $0.category == board }
        let letters = keys.filter { $0.effectiveAction == .typeText && $0.label.first?.isLetter == true }
        XCTAssertEqual(letters.map(\.label), LetterOrder.qwerty.letters(language: "es"))
        XCTAssertEqual(Array(keys.prefix(9)).map(\.label),
                       ["Space", "Delete", "Left", "Right", "Suggestion 1", "Suggestion 2", "Suggestion 3", "Q", "W"])
        for text in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", ".", "?", "!"] {
            XCTAssertTrue(keys.contains { $0.label == text && $0.effectiveAction == .typeText })
        }
        func key(_ label: String) throws -> CommunicationItem {
            try XCTUnwrap(keys.first { $0.label == label })
        }
        for label in ["H", "I", "!", "Space", "N", "O", "2"] {
            store.select(try key(label))
        }
        XCTAssertEqual(store.typedMessage, "Hi! No2")
        XCTAssertNil(store.gridLayout(for: board))
        XCTAssertEqual(try XCTUnwrap(store.addSpellingBoard(layout: .qwerty)), "QWERTY 2")
        store.flushConversationDraft()
        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertEqual(reloaded.typedMessage, "Hi! No2")
        XCTAssertEqual(reloaded.items.filter { $0.category == board }.map(\.label), keys.map(\.label))
    }

    @MainActor
    func testPredictionTilesCompleteCurrentWordAndStayUnavailableAtMidCursor() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("predictions.json"))
        let board = try XCTUnwrap(store.addSpellingBoard())
        let predictions = store.items.filter {
            $0.category == board && $0.effectiveAction == .completeTypedPrediction
        }
        XCTAssertEqual(predictions.map(\.message), ["0", "1", "2"])
        XCTAssertTrue(predictions.allSatisfy { store.typedPrediction(for: $0) == nil })
        store.typedMessage = "wa"
        store.typedCursorOffset = 1
        XCTAssertTrue(predictions.allSatisfy { store.typedPrediction(for: $0) == nil })
        store.select(predictions[0])
        XCTAssertEqual(store.typedMessage, "wa")
        store.typedCursorOffset = 2
        let available = try XCTUnwrap(predictions.first { store.typedPrediction(for: $0) != nil })
        let word = try XCTUnwrap(store.typedPrediction(for: available))
        XCTAssertTrue(word.lowercased().hasPrefix("wa"))
        XCTAssertEqual(store.displayLabel(for: available), word)
        let exported = try store.openBoardData(named: board)
        let imported = try OpenBoardFormat.importData(exported, fileExtension: "obf")
        XCTAssertEqual(imported.items.filter { $0.effectiveAction == .completeTypedPrediction }
            .map(\.label), ["Suggestion 1", "Suggestion 2", "Suggestion 3"])
        store.select(available)
        XCTAssertEqual(store.typedMessage, word + " ")
        XCTAssertEqual(store.typedCursorOffset, store.typedMessage.count)
    }

    @MainActor
    func testGridCursorInsertsAndDeletesAtGraphemeBoundaryAndSurvivesRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let board = try XCTUnwrap(store.addSpellingBoard())
        let keys = store.items.filter { $0.category == board }
        func key(_ label: String) throws -> CommunicationItem {
            try XCTUnwrap(keys.first { $0.label == label })
        }
        store.typedMessage = "A👩🏽‍💻B"
        store.typedCursorOffset = 2
        store.select(try key("Delete"))
        XCTAssertEqual(store.typedMessage, "AB")
        XCTAssertEqual(store.typedCursorOffset, 1)
        store.select(try key("C"))
        XCTAssertEqual(store.typedMessage, "AcB")
        XCTAssertEqual(store.typedCursorOffset, 2)
        store.select(try key("Left"))
        store.select(try key("Space"))
        XCTAssertEqual(store.typedMessage, "A cB")
        XCTAssertEqual(store.typedCursorOffset, 2)
        store.flushConversationDraft()
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.typedMessage, "A cB")
        XCTAssertEqual(restored.typedCursorOffset, 2)
        restored.select(try key("Right"))
        XCTAssertEqual(restored.typedCursorOffset, 3)
        restored.select(try key("Delete"))
        XCTAssertEqual(restored.typedMessage, "A B")
        XCTAssertEqual(restored.typedCursorOffset, 2)
        let firstConversation = restored.activeConversationID
        XCTAssertTrue(restored.addConversation("Another"))
        restored.typedMessage = "other"
        restored.typedCursorOffset = 1
        XCTAssertTrue(restored.switchConversation(to: firstConversation))
        XCTAssertEqual(restored.typedMessage, "A B")
        XCTAssertEqual(restored.typedCursorOffset, 2)
        restored.typedMessage = "A"
        restored.select(try key("Left"))
        XCTAssertEqual(restored.typedCursorOffset, 0)
    }
}
