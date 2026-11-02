import XCTest
@testable import OpenVoice

final class WordKeyboardKeyTests: XCTestCase {
    func testWordKeysComposeAtCursorAndHonorSpacing() {
        let want = WordKeyboardKey(label: "want", text: "want")
        let first = want.inserting(into: "I", at: 1)
        XCTAssertEqual(first.text, "I want ")
        XCTAssertEqual(first.cursorOffset, 7)

        let punctuation = WordKeyboardKey(label: "?", text: "?", spaceBefore: false)
        XCTAssertEqual(punctuation.inserting(into: "I want", at: 6).text, "I want? ")
        XCTAssertEqual(punctuation.inserting(into: "I want ", at: 7).text, "I want? ")

        let joined = WordKeyboardKey(label: "sun", text: "sun", spaceAfter: false)
        XCTAssertEqual(joined.inserting(into: "The", at: 3).text, "The sun")
        XCTAssertEqual(want.inserting(into: "I today", at: 2).text, "I want today")
        XCTAssertEqual(want.inserting(into: "I want", at: 100).cursorOffset, 12)
    }

    func testOlderSettingsUseStarterKeysAndCustomKeysSurviveCoding() throws {
        let oldData = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: oldData) as? [String: Any])
        json.removeValue(forKey: "wordKeyboardEnabled")
        json.removeValue(forKey: "wordKeyboardColumns")
        json.removeValue(forKey: "wordKeyboardKeys")
        let restoredOld = try JSONDecoder().decode(
            AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(restoredOld.wordKeyboardEnabled)
        XCTAssertEqual(restoredOld.wordsForKeyboard(language: "en").first?.text, "I")

        var settings = restoredOld
        let key = WordKeyboardKey(label: "Name", text: "Alex", spaceAfter: false)
        settings.setWordsForKeyboard([key], language: "en")
        settings.wordKeyboardEnabled = true
        settings.wordKeyboardColumns = 3
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.wordsForKeyboard(language: "en"), [key])
        XCTAssertEqual(restored.wordsForKeyboard(language: "es").first?.text, "Yo")
        XCTAssertEqual(restored.wordKeyboardColumns, 3)
        XCTAssertTrue(restored.wordKeyboardEnabled)
    }

    @MainActor
    func testWordKeysStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let profileID = store.activeProfileID
        let key = WordKeyboardKey(label: "Person", text: "Maya")
        store.settings.setWordsForKeyboard([key], language: "en")
        store.settings.wordKeyboardEnabled = true
        XCTAssertTrue(store.addProfile("Another communicator"))
        XCTAssertFalse(store.settings.wordKeyboardEnabled)
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.wordsForKeyboard(language: "en"), [key])
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.wordsForKeyboard(language: "en"), [key])
    }
}
