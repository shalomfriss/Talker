import XCTest
@testable import OpenVoice

final class PronunciationDictionaryTests: XCTestCase {
    func testCorrectionsUseWholeWordsPreferLongerPhrasesAndDoNotCascade() {
        let rules = [
            PronunciationRule(written: "AAC", spoken: "A A C", language: "en"),
            PronunciationRule(written: "New York", spoken: "new yawk", language: "en"),
            PronunciationRule(written: "York", spoken: "yorke", language: "en"),
            PronunciationRule(written: "A A C", spoken: "another", language: "en")
        ]
        let original = "AAC and aac in New York, not BAAC."
        XCTAssertEqual(PronunciationDictionary.applying(original, language: "en", rules: rules),
                       "A A C and A A C in new yawk, not BAAC.")
        XCTAssertEqual(original, "AAC and aac in New York, not BAAC.")
        XCTAssertEqual(PronunciationDictionary.applying("AAC", language: "es", rules: rules), "AAC")
    }

    func testValidationRejectsEmptyDuplicateAndMultilineCorrections() {
        let first = PronunciationRule(written: " AAC ", spoken: " A A C ", language: "en")
        let clean = PronunciationDictionary.cleaned(first, existing: [])!
        XCTAssertEqual(clean.written, "AAC")
        XCTAssertEqual(clean.spoken, "A A C")
        XCTAssertNil(PronunciationDictionary.cleaned(.init(written: "aac", spoken: "other", language: "en"),
                                                     existing: [clean]))
        XCTAssertNotNil(PronunciationDictionary.cleaned(.init(written: "aac", spoken: "a a ce", language: "es"),
                                                        existing: [clean]))
        XCTAssertNil(PronunciationDictionary.cleaned(.init(written: "one\ntwo", spoken: "one two", language: "en"),
                                                     existing: []))
        XCTAssertNil(PronunciationDictionary.cleaned(.init(written: "", spoken: "value", language: "en"),
                                                     existing: []))
    }

    @MainActor
    func testCorrectionsBelongToProfileAndBackupWhileHistoryKeepsWrittenText() throws {
        XCTAssertTrue(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)).pronunciationRules.isEmpty)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("voice.json")
        let source = CommunicationStore(storageURL: url)
        let firstID = source.activeProfileID
        let rule = PronunciationRule(written: "AAC", spoken: "A A C", language: "en")
        XCTAssertTrue(source.savePronunciationRule(rule))
        XCTAssertFalse(source.savePronunciationRule(.init(written: "aac", spoken: "other", language: "en")))
        source.settings.saveHistory = true
        source.speak("AAC please", saveToHistory: true)
        XCTAssertEqual(source.history.first?.text, "AAC please")
        source.stopSpeaking()

        XCTAssertTrue(source.addProfile("Second voice"))
        XCTAssertTrue(source.settings.pronunciationRules.isEmpty)
        XCTAssertTrue(source.switchProfile(to: firstID))
        XCTAssertEqual(source.settings.pronunciationRules, [rule])
        XCTAssertEqual(CommunicationStore(storageURL: url).settings.pronunciationRules, [rule])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.settings.pronunciationRules, [rule])
    }
}
