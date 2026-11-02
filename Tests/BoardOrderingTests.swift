import XCTest
@testable import OpenVoice

final class BoardOrderingTests: XCTestCase {
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
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.settings.boardFolders.isEmpty)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.boardFolder(for: "People nearby"), "School")
        XCTAssertEqual(CommunicationStore(storageURL: url).boardFolder(for: "People nearby"), "School")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.boardFolder(for: "People nearby"), "School")

        let selected = CommunicationStore(storageURL: directory.appendingPathComponent("selected.json"))
        XCTAssertTrue(selected.addBoardFolder("school"))
        let imported = try selected.addBoards(fromBackup: source.backupData(),
                                              selectedBoards: ["People nearby"])
        XCTAssertEqual(imported, ["People nearby"])
        XCTAssertEqual(selected.boardFolder(for: "People nearby"), "school")
        XCTAssertEqual(selected.settings.boardFolders, ["school"])
    }

    func testOlderSettingsDecodeWithoutBoardFolders() throws {
        let encoded = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "boardFolders")
        object.removeValue(forKey: "boardFolderAssignments")
        let older = try JSONSerialization.data(withJSONObject: object)
        let settings = try JSONDecoder().decode(AppSettings.self, from: older)
        XCTAssertTrue(settings.boardFolders.isEmpty)
        XCTAssertTrue(settings.boardFolderAssignments.isEmpty)
    }
}
