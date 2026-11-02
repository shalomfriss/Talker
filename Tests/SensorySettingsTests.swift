import XCTest
@testable import OpenVoice

final class SensorySettingsTests: XCTestCase {
    @MainActor
    func testPreferencesStayWithProfileRelaunchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: url)
        let profileID = store.activeProfileID
        store.settings.sensoryIntensity = .lively
        store.settings.sensoryMotionEnabled = false
        store.settings.sensoryHapticsEnabled = true
        store.settings.soundscapeVolume = 0.42
        XCTAssertEqual(CommunicationStore(storageURL: url).settings.sensoryIntensity, .lively)
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.settings.sensoryIntensity, .calm)
        XCTAssertTrue(store.settings.sensoryMotionEnabled)
        XCTAssertFalse(store.settings.sensoryHapticsEnabled)
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.settings.sensoryIntensity, .lively)
        XCTAssertFalse(store.settings.sensoryMotionEnabled)
        XCTAssertTrue(store.settings.sensoryHapticsEnabled)
        XCTAssertEqual(store.settings.soundscapeVolume, 0.42)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.sensoryIntensity, .lively)
        XCTAssertFalse(restored.settings.sensoryMotionEnabled)
        XCTAssertTrue(restored.settings.sensoryHapticsEnabled)
        XCTAssertEqual(restored.settings.soundscapeVolume, 0.42)
    }

    func testOlderAndUnknownPreferencesUseGentleDefaults() throws {
        let encoded = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "sensoryIntensity")
        object.removeValue(forKey: "sensoryMotionEnabled")
        object.removeValue(forKey: "sensoryHapticsEnabled")
        object.removeValue(forKey: "soundscapeVolume")
        let older = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(older.sensoryIntensity, .calm)
        XCTAssertTrue(older.sensoryMotionEnabled)
        XCTAssertFalse(older.sensoryHapticsEnabled)
        XCTAssertEqual(older.soundscapeVolume, 0.3)
        object["sensoryIntensity"] = "Unknown"
        let unknown = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(unknown.sensoryIntensity, .calm)
    }
}
