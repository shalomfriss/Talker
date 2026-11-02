import XCTest
@testable import OpenVoice

final class PhraseShortcutTests: XCTestCase {
    func testLegacyPhraseAndShortcutExpansion() throws {
        let old = try JSONDecoder().decode(SavedPhrase.self, from: Data(#"{"text":"Thank you."}"#.utf8))
        XCTAssertNil(old.shortcut)
        let saved = SavedPhrase(text: "Thank you.", shortcut: "ty")
        XCTAssertEqual(PhraseShortcut.matches("Please TY", phrases: [old, saved]).map(\.text), ["Thank you."])
        XCTAssertEqual(PhraseShortcut.expanding("Please TY", with: saved.text), "Please Thank you. ")
        XCTAssertTrue(PhraseShortcut.matches("Please TY ", phrases: [saved]).isEmpty)
    }

    @MainActor
    func testShortcutMustBeValidAndUniqueAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertFalse(source.addPhrase("Hello", shortcut: "x"))
        XCTAssertFalse(source.addPhrase("Hello", shortcut: "two words"))
        XCTAssertTrue(source.addPhrase("Hello", shortcut: "HI"))
        XCTAssertFalse(source.addPhrase("Goodbye", shortcut: "hi"))
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "Hello" })
        XCTAssertEqual(phrase.shortcut, "hi")
        XCTAssertTrue(source.updatePhraseDetails(phrase, text: "Hello there", shortcut: "hey"))
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .phrases.first { $0.id == phrase.id }?.shortcut, "hey")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.shortcut, "hey")
    }
}
