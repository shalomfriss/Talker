import XCTest
@testable import OpenVoice

final class SpeechVolumeTests: XCTestCase {
    @MainActor
    func testLocalSpeechVolumeAppliesToUtterancesAndProfiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstProfile = store.activeProfileID
        store.settings.speechVolume = 0.4
        store.settings.speechPitch = 1.35
        XCTAssertEqual(store.makeUtterance("Hello", language: "en").volume, 0.4, accuracy: 0.001)
        XCTAssertEqual(store.makeUtterance("Hello", language: "en").pitchMultiplier, 1.35, accuracy: 0.001)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).settings.speechVolume, 0.4)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).settings.speechPitch, 1.35, accuracy: 0.001)

        store.settings.speechMuted = true
        XCTAssertEqual(store.makeUtterance("Hello", language: "en").volume, 0)
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.settings.speechVolume, 1)
        XCTAssertEqual(store.settings.speechPitch, 1)
        XCTAssertFalse(store.settings.speechMuted)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.settings.speechPlaybackVolume, 0)
        XCTAssertEqual(store.settings.speechPitch, 1.35, accuracy: 0.001)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.speechVolume, 0.4)
        XCTAssertEqual(restored.settings.speechPitch, 1.35, accuracy: 0.001)
        XCTAssertTrue(restored.settings.speechMuted)
    }

    func testOlderAndOutOfRangeSettingsUseSafeSpeechLevels() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "speechVolume")
        object.removeValue(forKey: "speechPitch")
        object.removeValue(forKey: "speechMuted")
        let older = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(older.speechPlaybackVolume, 1)
        XCTAssertEqual(older.speechPitch, 1)

        object["speechVolume"] = -3
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object)).speechVolume, 0.1)
        object["speechVolume"] = 6
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object)).speechVolume, 1)
        object["speechPitch"] = -3
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object)).speechPitch, 0.5)
        object["speechPitch"] = 6
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object)).speechPitch, 2)
    }
}
