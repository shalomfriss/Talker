import XCTest
@testable import OpenVoice

final class ChoiceBoardTransferTests: XCTestCase {
    func testOlderChoiceBoardDecodesWithDefaultFolderAndLayout() throws {
        let board = ChoiceBoard(title: "Lunch", options: [ChoiceOption(label: "Soup"), ChoiceOption(label: "Rice")])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(board)) as? [String: Any])
        json.removeValue(forKey: "folder")
        json.removeValue(forKey: "layout")
        let decoded = try JSONDecoder().decode(ChoiceBoard.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.folder)
        XCTAssertEqual(decoded.effectiveLayout, .grid)
        XCTAssertEqual(decoded.title, "Lunch")
    }

    func testChoiceColorCanBeClearedWithoutChangingSourceWord() {
        let word = CommunicationItem(label: "Soup", symbol: "🥣", message: "Soup", category: "Food",
                                     backgroundColorHex: "#FFBBDD", borderColorHex: "#663300")
        var option = ChoiceOption(item: word)
        option.backgroundColorHex = nil
        option.borderColorHex = nil
        let resolved = option.resolved(using: [word])
        XCTAssertNil(resolved.communicationItem.backgroundColorHex)
        XCTAssertNil(resolved.communicationItem.borderColorHex)
        XCTAssertEqual(word.backgroundColorHex, "#FFBBDD")
    }

    func testOlderChoiceOptionsDecodeWithoutColors() throws {
        let option = ChoiceOption(label: "Water")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(option)) as? [String: Any])
        json.removeValue(forKey: "backgroundColorHex")
        json.removeValue(forKey: "borderColorHex")
        let decoded = try JSONDecoder().decode(ChoiceOption.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.label, "Water")
        XCTAssertNil(decoded.backgroundColorHex)
        XCTAssertNil(decoded.borderColorHex)
    }

    @MainActor
    func testChoiceColorsPersistAndBoardFileImportsAsIndependentCopy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let photo = Data([1, 2, 3, 4])
        let voice = Data([5, 6, 7])
        source.addItem(label: "Soup", symbol: "🥣", message: "I want soup", category: "Food",
                       imageData: photo, audioData: voice, backgroundColorHex: "#fbd", borderColorHex: "#630")
        let word = try XCTUnwrap(source.items.first { $0.label == "Soup" && $0.isCustom })
        let original = ChoiceBoard(title: "Lunch", options: [ChoiceOption(item: word), ChoiceOption(label: "Rice")],
                                   folder: "Meals", layout: .largeFirst)
        XCTAssertTrue(source.saveChoiceBoard(original))
        let saved = try XCTUnwrap(source.choiceBoards.first { $0.id == original.id })
        XCTAssertEqual(saved.options[0].backgroundColorHex, "#FFBBDD")
        XCTAssertEqual(saved.options[0].borderColorHex, "#663300")
        XCTAssertEqual(saved.effectiveLayout, .largeFirst)

        let exported = try ChoiceBoardTransfer.exportData(saved, using: source.items)
        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let imported = try recipient.importChoiceBoard(exported)
        XCTAssertNotEqual(imported.id, original.id)
        XCTAssertNotEqual(imported.options[0].id, word.id)
        XCTAssertEqual(imported.options[0].message, "I want soup")
        XCTAssertEqual(imported.options[0].imageData, photo)
        XCTAssertEqual(imported.options[0].audioData, voice)
        XCTAssertEqual(imported.options[0].backgroundColorHex, "#FFBBDD")
        XCTAssertEqual(imported.options[0].borderColorHex, "#663300")
        XCTAssertEqual(imported.folder, "Meals")
        XCTAssertEqual(imported.effectiveLayout, .largeFirst)
        XCTAssertEqual(try recipient.importChoiceBoard(exported).title, "Lunch (imported 2)")
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
            .choiceBoards.first(where: { $0.id == imported.id }), imported)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(recipient.backupData())
        XCTAssertEqual(restored.choiceBoards.first(where: { $0.id == imported.id }), imported)
    }

    @MainActor
    func testFolderOrderPersistsWithoutMovingBoardsInOtherFolders() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("folders.json")
        let store = CommunicationStore(storageURL: file)
        let options = [ChoiceOption(label: "Yes"), ChoiceOption(label: "No")]
        let first = ChoiceBoard(title: "Lunch", options: options, folder: " Meals ")
        let other = ChoiceBoard(title: "Play", options: options, folder: "Activities")
        let second = ChoiceBoard(title: "Dinner", options: options, folder: "meals")
        XCTAssertTrue(store.saveChoiceBoard(first))
        XCTAssertTrue(store.saveChoiceBoard(other))
        XCTAssertTrue(store.saveChoiceBoard(second))
        XCTAssertEqual(store.choiceBoardFolders, ["Meals", "Activities"])
        XCTAssertEqual(store.choiceBoards.first(where: { $0.id == second.id })?.folder, "Meals")
        XCTAssertTrue(store.moveChoiceBoards(ids: [first.id, second.id],
                                             fromOffsets: IndexSet(integer: 1), toOffset: 0))
        XCTAssertEqual(store.choiceBoards.filter { [first.id, other.id, second.id].contains($0.id) }
            .map(\.id), [second.id, other.id, first.id])
        XCTAssertEqual(CommunicationStore(storageURL: file).choiceBoards
            .filter { [first.id, other.id, second.id].contains($0.id) }.map(\.id),
            [second.id, other.id, first.id])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.choiceBoards.filter { [first.id, other.id, second.id].contains($0.id) }
            .map(\.id), [second.id, other.id, first.id])
        store.settings.choiceBoardEditingLocked = true
        XCTAssertFalse(store.moveChoiceBoards(ids: [second.id, first.id],
                                              fromOffsets: IndexSet(integer: 0), toOffset: 2))
    }

    @MainActor
    func testBoardImportRejectsWrongFileDuplicateChoicesAndEditingLock() throws {
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        XCTAssertThrowsError(try store.importChoiceBoard(Data("{\"hello\":true}".utf8))) { error in
            XCTAssertEqual(error as? ChoiceBoardTransferError, .unsupportedFormat)
        }
        let board = ChoiceBoard(title: "Food", options: [ChoiceOption(label: "Soup"), ChoiceOption(label: "Rice")])
        let valid = try ChoiceBoardTransfer.exportData(board, using: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var boardJSON = try XCTUnwrap(json["board"] as? [String: Any])
        var options = try XCTUnwrap(boardJSON["options"] as? [[String: Any]])
        options[1]["label"] = "soup"
        boardJSON["options"] = options
        json["board"] = boardJSON
        let duplicate = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try store.importChoiceBoard(duplicate))
        store.settings.choiceBoardEditingLocked = true
        XCTAssertThrowsError(try store.importChoiceBoard(valid)) { error in
            XCTAssertEqual(error as? ChoiceBoardTransferError, .editingLocked)
        }
    }
}
