import XCTest
@testable import OpenVoice

final class BoardOrderingTests: XCTestCase {
    @MainActor
    func testCopyAndMoveButtonBetweenBoardsPreservesContentAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        XCTAssertTrue(store.addBoard("My drinks"))
        XCTAssertTrue(store.addBoard("My day"))
        let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
        store.addItem(label: "Coffee", symbol: "☕️", message: "I want coffee",
                      category: "My drinks", imageData: photo, action: .addToMessage,
                      spanishLabel: "Café", spanishMessage: "Quiero café",
                      backgroundColorHex: "#DDEBFF")
        let original = try XCTUnwrap(store.items.first { $0.label == "Coffee" })
        let copiedID = try XCTUnwrap(store.copyItem(original.id, to: "My day"))
        let copied = try XCTUnwrap(store.items.first { $0.id == copiedID })
        XCTAssertNotEqual(copied.id, original.id)
        XCTAssertEqual(copied.category, "My day")
        XCTAssertEqual(copied.imageData, photo)
        XCTAssertEqual(copied.message, original.message)
        XCTAssertEqual(copied.backgroundColorHex, original.backgroundColorHex)
        XCTAssertEqual(store.translation(for: copied)?.message, "Quiero café")
        XCTAssertTrue(store.items.contains { $0.id == original.id && $0.category == "My drinks" })

        XCTAssertTrue(store.moveItem(original.id, to: "My day"))
        XCTAssertFalse(store.moveItem(original.id, to: "My day"))
        XCTAssertFalse(store.items.contains { $0.id == original.id && $0.category == "My drinks" })
        XCTAssertEqual(store.items.filter { $0.category == "My day" && $0.label == "Coffee" }.count, 2)

        store.addItem(label: "Open my day", symbol: "➡️", message: "Open my day",
                      category: "My drinks", imageData: nil, destinationBoard: "My day",
                      action: .openBoard)
        let link = try XCTUnwrap(store.items.first { $0.label == "Open my day" })
        XCTAssertNil(store.copyItem(link.id, to: "My day"))
        XCTAssertFalse(store.moveItem(link.id, to: "My day"))
        XCTAssertEqual(store.items.first { $0.id == link.id }?.category, "My drinks")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.id == copiedID }?.imageData, photo)
        XCTAssertEqual(restored.translation(for: try XCTUnwrap(restored.items.first { $0.id == copiedID }))?.label,
                       "Café")
        XCTAssertEqual(restored.items.first { $0.id == original.id }?.category, "My day")
    }

    func testPagedBoardSlotsMatchFullLayoutOnLargeSparseBoard() {
        let items = (0..<1_000).map { index in
            CommunicationItem(label: "Word \(index)", symbol: "💬", message: "Word \(index)", category: "Core")
        }
        let emptyPositions: Set<Int> = [0, 3, 28, 1_100]
        let layout = BoardGridLayout(columns: 4, rows: 4)
        let allSlots = BoardSlotLayout.slots(for: items, emptyPositions: emptyPositions)
        XCTAssertEqual(BoardSlotLayout.slotCount(itemCount: items.count, emptyPositions: emptyPositions),
                       allSlots.count)

        for page in 0..<layout.pageCount(for: allSlots.count) {
            let range = layout.range(for: page, itemCount: allSlots.count)
            let expected = Array(allSlots[range])
                + Array(repeating: nil, count: layout.pageCapacity - range.count)
            let actual = BoardSlotLayout.pageSlots(for: items, emptyPositions: emptyPositions,
                                                    layout: layout, page: page)
            XCTAssertEqual(actual.map { $0?.id }, expected.map { $0?.id }, "Page \(page)")
        }
    }

    @MainActor
    func testMoveChangesVisibleAndPinnedOrderWithoutMovingWords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let original = store.categories
        XCTAssertGreaterThan(original.count, 1)
        let first = original[0]
        let second = original[1]
        let wordIDs = store.items.map(\.id)
        store.setBoardPinned(true, board: first)
        store.setBoardPinned(true, board: second)
        XCTAssertTrue(store.moveBoard(second, by: -1))
        XCTAssertEqual(Array(store.categories.prefix(2)), [second, first])
        XCTAssertEqual(Array(store.visibleBoards.prefix(2)), [second, first])
        XCTAssertEqual(store.pinnedBoards, [second, first])
        XCTAssertEqual(store.items.map(\.id), wordIDs)
        XCTAssertFalse(store.moveBoard(second, by: -1))
        XCTAssertFalse(store.moveBoard(first, by: 2))
        XCTAssertFalse(store.moveBoard("Unknown", by: 1))
    }

    @MainActor
    func testBoardOrderPersistsThroughRelaunchProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: url)
        XCTAssertTrue(source.addBoard("People nearby"))
        XCTAssertTrue(source.moveBoard("People nearby", by: -1))
        let reordered = source.categories
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertNotEqual(source.categories, reordered)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.categories, reordered)
        XCTAssertEqual(CommunicationStore(storageURL: url).categories, reordered)
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try target.importBackup(source.backupData())
        XCTAssertEqual(target.categories, reordered)
    }

    @MainActor
    func testHiddenBoardCanMoveAndKeepsItsVisibility() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let second = store.categories[1]
        XCTAssertTrue(store.setBoardVisible(false, for: second))
        XCTAssertTrue(store.moveBoard(second, by: -1))
        XCTAssertEqual(store.categories.first, second)
        XCTAssertFalse(store.visibleBoards.contains(second))
        XCTAssertTrue(store.setBoardVisible(true, for: second))
        XCTAssertEqual(store.visibleBoards.first, second)
    }

    @MainActor
    func testFoldersKeepBoardOrderWordsAndVisibilityWhileNamesChange() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        XCTAssertTrue(store.addBoard("Family circle"))
        XCTAssertTrue(store.addBoardFolder("People"))
        XCTAssertTrue(store.addBoardFolder("Places"))
        XCTAssertFalse(store.addBoardFolder("people"))
        XCTAssertFalse(store.addBoardFolder(String(repeating: "x", count: 41)))
        XCTAssertTrue(store.moveBoardFolder("Places", by: -1))
        XCTAssertEqual(store.settings.boardFolders, ["Places", "People"])
        XCTAssertFalse(store.moveBoardFolder("Places", by: -1))
        XCTAssertTrue(store.moveBoardFolder("Places", by: 1))
        let originalOrder = store.categories
        let wordIDs = store.items.map(\.id)
        XCTAssertTrue(store.setBoardFolder("People", for: "Needs"))
        XCTAssertTrue(store.setBoardFolder("People", for: "Family circle"))
        XCTAssertFalse(store.setBoardFolder("Missing", for: "Needs"))
        XCTAssertEqual(store.visibleBoards(in: "People"), ["Needs", "Family circle"])
        XCTAssertEqual(store.categories, originalOrder)
        XCTAssertEqual(store.items.map(\.id), wordIDs)

        XCTAssertTrue(store.setBoardVisible(false, for: "Needs"))
        XCTAssertEqual(store.visibleBoards(in: "People"), ["Family circle"])
        XCTAssertTrue(store.renameBoardFolder("People", to: "Family"))
        XCTAssertTrue(store.renameBoard("Family circle", to: "Relatives"))
        XCTAssertEqual(store.boardFolder(for: "Relatives"), "Family")
        XCTAssertEqual(store.visibleBoards(in: "Family"), ["Relatives"])
        XCTAssertTrue(store.deleteBoardFolder("Family"))
        XCTAssertNil(store.boardFolder(for: "Relatives"))
        XCTAssertTrue(store.categories.contains("Relatives"))
        XCTAssertEqual(store.items.map(\.id), wordIDs)
    }

    @MainActor
    func testFoldersPersistAcrossProfilesBackupAndSelectedBoardImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: url)
        XCTAssertTrue(source.addBoard("People nearby"))
        XCTAssertTrue(source.addBoardFolder("School"))
        XCTAssertTrue(source.setBoardFolder("School", for: "People nearby"))
        XCTAssertTrue(source.setBoardFolderVoiceIdentifier("school.voice", for: "School"))
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.settings.boardFolders.isEmpty)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.boardFolder(for: "People nearby"), "School")
        XCTAssertEqual(CommunicationStore(storageURL: url).boardFolder(for: "People nearby"), "School")
        XCTAssertEqual(CommunicationStore(storageURL: url).settings.boardFolderVoiceIdentifiers["School"], "school.voice")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.boardFolder(for: "People nearby"), "School")
        XCTAssertEqual(restored.settings.boardFolderVoiceIdentifiers["School"], "school.voice")

        let selected = CommunicationStore(storageURL: directory.appendingPathComponent("selected.json"))
        XCTAssertTrue(selected.addBoardFolder("school"))
        let imported = try selected.addBoards(fromBackup: source.backupData(),
                                              selectedBoards: ["People nearby"])
        XCTAssertEqual(imported, ["People nearby"])
        XCTAssertEqual(selected.boardFolder(for: "People nearby"), "school")
        XCTAssertEqual(selected.settings.boardFolders, ["school"])
        XCTAssertEqual(selected.settings.boardFolderVoiceIdentifiers["school"], "school.voice")
    }

    func testOlderSettingsDecodeWithoutBoardFolders() throws {
        let encoded = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "boardFolders")
        object.removeValue(forKey: "boardFolderAssignments")
        object.removeValue(forKey: "boardFolderVoiceIdentifiers")
        let older = try JSONSerialization.data(withJSONObject: object)
        let settings = try JSONDecoder().decode(AppSettings.self, from: older)
        XCTAssertTrue(settings.boardFolders.isEmpty)
        XCTAssertTrue(settings.boardFolderAssignments.isEmpty)
        XCTAssertTrue(settings.boardFolderVoiceIdentifiers.isEmpty)
    }
}
