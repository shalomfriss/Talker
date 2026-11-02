import XCTest
@testable import OpenVoice

final class KeyboardKeyClusterTests: XCTestCase {
    func testSixBalancedGroupsPreserveEveryKeyAndItsOrder() {
        let english = LetterOrder.commonFirst.letters(language: "en")
        let spanish = LetterOrder.alphabetical.letters(language: "es")
        let symbols = Array("0123456789").map(String.init) + ["-", "/", ":", ";", "(", ")", "$", "&", "@"]
        for keys in [english, spanish, symbols] {
            let groups = KeyboardKeyCluster.groups(for: keys)
            XCTAssertEqual(groups.count, 6)
            XCTAssertEqual(groups.flatMap(\.keys), keys)
            let sizes = groups.map { $0.keys.count }
            XCTAssertLessThanOrEqual((sizes.max() ?? 0) - (sizes.min() ?? 0), 1)
        }
    }

    func testOlderSettingsWithoutGroupedKeysKeepTheStandardKeyboard() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "groupedKeyboardKeys")
        json.removeValue(forKey: "tenKeyKeyboardEnabled")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        let settings = try JSONDecoder().decode(AppSettings.self, from: oldData)
        XCTAssertFalse(settings.groupedKeyboardKeys)
        XCTAssertFalse(settings.tenKeyKeyboardEnabled)
    }

    func testTenKeyGroupsCoverLettersAndTheSettingExcludesSixGroupMode() throws {
        for language in ["en", "es"] {
            let letters = LetterOrder.alphabetical.letters(language: language)
            let groups = KeyboardKeyCluster.groups(for: letters)
            XCTAssertEqual(groups.count, 6)
            XCTAssertEqual(groups.first?.keys, ["A", "B", "C", "D", "E"])
            XCTAssertEqual(groups.flatMap(\.keys), letters)
        }
        var settings = AppSettings()
        settings.selectGroupedKeyboardKeys(true)
        settings.selectTenKeyKeyboard(true)
        XCTAssertTrue(settings.tenKeyKeyboardEnabled)
        XCTAssertFalse(settings.groupedKeyboardKeys)
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertTrue(restored.tenKeyKeyboardEnabled)
        XCTAssertFalse(restored.groupedKeyboardKeys)
        var next = restored
        next.selectGroupedKeyboardKeys(true)
        XCTAssertFalse(next.tenKeyKeyboardEnabled)
        XCTAssertTrue(next.groupedKeyboardKeys)
    }

    @MainActor
    func testTenKeyChoiceStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        store.settings.selectTenKeyKeyboard(true)
        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertFalse(store.settings.tenKeyKeyboardEnabled)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertTrue(CommunicationStore(storageURL: file).settings.tenKeyKeyboardEnabled)
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertTrue(imported.settings.tenKeyKeyboardEnabled)
    }
}
