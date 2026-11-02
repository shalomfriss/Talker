import XCTest
@testable import OpenVoice

final class PinnedBoardTests: XCTestCase {
    @MainActor
    func testPinnedBoardsFollowRenameDeleteProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.addBoard("People nearby"))
        source.setBoardPinned(true, board: "Needs")
        source.setBoardPinned(true, board: "People nearby")
        source.setBoardPinned(true, board: "Needs")
        source.setBoardPinned(true, board: "Missing")
        XCTAssertEqual(source.pinnedBoards, ["Needs", "People nearby"])
        XCTAssertTrue(source.renameBoard("People nearby", to: "Family"))
        XCTAssertEqual(source.pinnedBoards, ["Needs", "Family"])
        source.setBoardPinned(false, board: "Needs")
        XCTAssertEqual(source.pinnedBoards, ["Family"])

        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.pinnedBoards.isEmpty)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.pinnedBoards, ["Family"])

        let reloaded = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertEqual(reloaded.pinnedBoards, ["Family"])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.pinnedBoards, ["Family"])
        XCTAssertTrue(source.deleteBoard("Family"))
        XCTAssertTrue(source.pinnedBoards.isEmpty)
    }

    func testOlderSettingsDefaultToNoPinnedBoards() throws {
        let encoded = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "pinnedBoards")
        let older = try JSONSerialization.data(withJSONObject: object)
        XCTAssertTrue(try JSONDecoder().decode(AppSettings.self, from: older).pinnedBoards.isEmpty)
    }
}
