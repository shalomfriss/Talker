import XCTest
@testable import OpenVoice

final class HomeBoardTests: XCTestCase {
    @MainActor
    func testHomeBoardFollowsProfileBackupRenameHideAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.addBoard("Garden"))
        XCTAssertTrue(store.setHomeBoard("Garden"))
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).homeBoard, "Garden")

        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.homeBoard, "Core")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.homeBoard, "Garden")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.homeBoard, "Garden")

        XCTAssertTrue(store.renameBoard("Garden", to: "Outside"))
        XCTAssertEqual(store.homeBoard, "Outside")
        XCTAssertTrue(store.setBoardVisible(false, for: "Outside"))
        XCTAssertEqual(store.homeBoard, "Core")
        XCTAssertTrue(store.setBoardVisible(true, for: "Outside"))
        XCTAssertTrue(store.setHomeBoard("Outside"))
        XCTAssertTrue(store.deleteBoard("Outside"))
        XCTAssertEqual(store.homeBoard, "Core")
    }

    func testOlderAndUnavailableHomeBoardsResolveToVisibleBoard() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "homeBoardName")
        let older = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(older.homeBoardName, "Core")
        XCTAssertEqual(HomeBoard.resolved("food", categories: ["Core", "Food"], hiddenBoards: []), "Food")
        XCTAssertEqual(HomeBoard.resolved("Food", categories: ["Core", "Food"], hiddenBoards: ["Food"]), "Core")
        XCTAssertEqual(HomeBoard.resolved("Missing", categories: ["Core", "Food"], hiddenBoards: ["Core"]), "Food")
    }
}
