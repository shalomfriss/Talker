import XCTest
@testable import OpenVoice

final class SavedPhraseOrderingTests: XCTestCase {
    func testOlderSettingsDefaultToNoRecentPhraseTracking() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "recentPhrasesEnabled")
        json.removeValue(forKey: "recentPhraseIDs")
        let restored = try JSONDecoder().decode(AppSettings.self,
            from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(restored.recentPhrasesEnabled)
        XCTAssertTrue(restored.recentPhraseIDs.isEmpty)
    }

    @MainActor
    func testRecentPhrasesTrackUseWithoutMovingFoldersAndSurviveBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(store.addPhrase("Ask for water", folder: "Needs"))
        XCTAssertTrue(store.addPhrase("Ask for a break", folder: "Needs"))
        let water = try XCTUnwrap(store.phrases.first { $0.text == "Ask for water" })
        let pause = try XCTUnwrap(store.phrases.first { $0.text == "Ask for a break" })
        let originalOrder = store.phrases.map(\.id)
        store.speakPhrase(water)
        XCTAssertTrue(store.recentPhrases.isEmpty)

        store.settings.recentPhrasesEnabled = true
        store.speakPhrase(water)
        XCTAssertTrue(store.appendTypedPhrase(pause))
        store.recordRecentPhrase(water)
        XCTAssertEqual(store.recentPhrases.map(\.id), [water.id, pause.id])
        XCTAssertEqual(store.phrases.map(\.id), originalOrder)

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertFalse(store.settings.recentPhrasesEnabled)
        XCTAssertTrue(store.recentPhrases.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(store.recentPhrases.map(\.id), [water.id, pause.id])
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).recentPhrases.map(\.id), [water.id, pause.id])
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.recentPhrases.map(\.id), [water.id, pause.id])

        store.deletePhrase(water)
        XCTAssertEqual(store.recentPhrases.map(\.id), [pause.id])
        store.clearRecentPhrases()
        XCTAssertTrue(store.recentPhrases.isEmpty)
    }

    @MainActor
    func testRecentPhraseListKeepsTwelveDistinctItems() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        store.settings.recentPhrasesEnabled = true
        for number in 1...13 {
            XCTAssertTrue(store.addPhrase("Recent test \(number)"))
            let phrase = try XCTUnwrap(store.phrases.first { $0.text == "Recent test \(number)" })
            store.recordRecentPhrase(phrase)
        }
        XCTAssertEqual(store.recentPhrases.count, 12)
        XCTAssertEqual(store.recentPhrases.first?.text, "Recent test 13")
        XCTAssertFalse(store.recentPhrases.contains { $0.text == "Recent test 1" })
    }

    @MainActor
    func testPhraseOrderStaysWithinFolderAndSurvivesProfileBackupAndRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(store.addPhrase("First need", folder: "Needs"))
        XCTAssertTrue(store.addPhrase("Place one", folder: "Places"))
        XCTAssertTrue(store.addPhrase("Second need", folder: "Needs"))
        XCTAssertTrue(store.addPhrase("Place two", folder: "Places"))
        XCTAssertTrue(store.addPhrase("Third need", folder: "Needs"))

        let second = try XCTUnwrap(store.phrases.first { $0.text == "Second need" })
        let needs = { store.phrases.filter { $0.folder == "Needs" }.map(\.text) }
        let places = store.phrases.filter { $0.folder == "Places" }.map(\.text)
        XCTAssertTrue(store.canMovePhrase(second, by: -1))
        XCTAssertTrue(store.movePhrase(second, by: -1))
        XCTAssertEqual(needs(), ["Second need", "First need", "Third need"])
        XCTAssertEqual(store.phrases.filter { $0.folder == "Places" }.map(\.text), places)
        XCTAssertFalse(store.canMovePhrase(second, by: -1))
        XCTAssertFalse(store.movePhrase(second, by: -1))
        XCTAssertFalse(store.movePhrase(second, by: 2))

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertFalse(store.phrases.contains { $0.text == "Second need" })
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(needs(), ["Second need", "First need", "Third need"])
        let reopened = CommunicationStore(storageURL: sourceURL)
        XCTAssertEqual(reopened.phrases.filter { $0.folder == "Needs" }.map(\.text), needs())
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.phrases.filter { $0.folder == "Needs" }.map(\.text), needs())
        XCTAssertEqual(restored.phrases.filter { $0.folder == "Places" }.map(\.text), places)
    }
}
