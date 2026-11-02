import XCTest
@testable import OpenVoice

final class TwoBoardsSettingsTests: XCTestCase {
    @MainActor
    func testTwoBoardChoiceStaysWithProfileRelaunchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstProfile = store.activeProfileID
        store.settings.twoBoardsEnabled = true
        XCTAssertTrue(CommunicationStore(storageURL: sourceURL).settings.twoBoardsEnabled)

        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertFalse(store.settings.twoBoardsEnabled)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertTrue(store.settings.twoBoardsEnabled)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertTrue(restored.settings.twoBoardsEnabled)
    }

    func testOlderSettingsDefaultToOneBoard() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "twoBoardsEnabled")
        let older = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(older.twoBoardsEnabled)
    }
}
