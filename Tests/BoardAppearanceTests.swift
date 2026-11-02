import XCTest
@testable import OpenVoice

final class BoardAppearanceTests: XCTestCase {
    @MainActor
    func testVisibilityHidesNavigationButKeepsBoardContentAndPin() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        store.setBoardPinned(true, board: "Needs")
        XCTAssertTrue(store.setBoardVisible(false, for: "Needs"))
        XCTAssertFalse(store.visibleBoards.contains("Needs"))
        XCTAssertFalse(store.pinnedBoards.contains("Needs"))
        XCTAssertTrue(store.categories.contains("Needs"))
        XCTAssertTrue(store.items.contains { $0.category == "Needs" })
        XCTAssertTrue(store.setBoardVisible(true, for: "Needs"))
        XCTAssertTrue(store.pinnedBoards.contains("Needs"))
    }

    @MainActor
    func testIconAndVisibilityFollowRenameDeleteProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.addBoard("People nearby"))
        XCTAssertTrue(source.setBoardIcon("👥", for: "People nearby"))
        XCTAssertTrue(source.setBoardVisible(false, for: "People nearby"))
        XCTAssertTrue(source.setBoardTileLabelsVisible(false, for: "People nearby"))
        XCTAssertTrue(source.renameBoard("People nearby", to: "Family"))
        XCTAssertEqual(source.boardIcon(for: "Family"), "👥")
        XCTAssertFalse(source.visibleBoards.contains("Family"))
        XCTAssertFalse(source.boardTileLabelsVisible(for: "Family"))
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertNil(source.boardIcon(for: "Family"))
        XCTAssertTrue(source.boardTileLabelsVisible(for: "Family"))
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.boardIcon(for: "Family"), "👥")
        XCTAssertFalse(source.boardTileLabelsVisible(for: "Family"))

        let reloaded = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertEqual(reloaded.boardIcon(for: "Family"), "👥")
        XCTAssertFalse(reloaded.visibleBoards.contains("Family"))
        XCTAssertFalse(reloaded.boardTileLabelsVisible(for: "Family"))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.boardIcon(for: "Family"), "👥")
        XCTAssertFalse(restored.visibleBoards.contains("Family"))
        XCTAssertFalse(restored.boardTileLabelsVisible(for: "Family"))
        XCTAssertTrue(source.deleteBoard("Family"))
        XCTAssertNil(source.boardIcon(for: "Family"))
        XCTAssertFalse(source.settings.hiddenBoards.contains("Family"))
        XCTAssertFalse(source.settings.boardsWithoutTileLabels.contains("Family"))
    }

    @MainActor
    func testLastVisibleBoardAndInvalidIconsAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        for board in store.visibleBoards.dropLast() {
            XCTAssertTrue(store.setBoardVisible(false, for: board))
        }
        let last = try XCTUnwrap(store.visibleBoards.first)
        XCTAssertFalse(store.setBoardVisible(false, for: last))
        XCTAssertEqual(store.visibleBoards, [last])
        XCTAssertFalse(store.setBoardIcon("abcde", for: last))
        XCTAssertNil(store.boardIcon(for: last))
        XCTAssertFalse(store.setBoardIcon("👋", for: "Unknown"))
        XCTAssertFalse(store.setBoardVisible(false, for: "Unknown"))
        XCTAssertFalse(store.setBoardTileLabelsVisible(false, for: "Unknown"))
    }

    @MainActor
    func testSelectedBackupCopiesIconAndShowsImportedBoard() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.setBoardIcon("🧩", for: "Needs"))
        XCTAssertTrue(source.setBoardVisible(false, for: "Needs"))
        XCTAssertTrue(source.setBoardTileLabelsVisible(false, for: "Needs"))
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        let imported = try target.addBoards(fromBackup: source.backupData(), selectedBoards: ["Needs"])
        let name = try XCTUnwrap(imported.first)
        XCTAssertEqual(target.boardIcon(for: name), "🧩")
        XCTAssertTrue(target.visibleBoards.contains(name))
        XCTAssertFalse(target.boardTileLabelsVisible(for: name))
    }

    func testOlderSettingsDefaultToVisibleBoardsWithoutIcons() throws {
        let encoded = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "boardIcons")
        object.removeValue(forKey: "hiddenBoards")
        object.removeValue(forKey: "boardsWithoutTileLabels")
        let older = try JSONSerialization.data(withJSONObject: object)
        let settings = try JSONDecoder().decode(AppSettings.self, from: older)
        XCTAssertTrue(settings.boardIcons.isEmpty)
        XCTAssertTrue(settings.hiddenBoards.isEmpty)
        XCTAssertTrue(settings.boardsWithoutTileLabels.isEmpty)
    }
}
