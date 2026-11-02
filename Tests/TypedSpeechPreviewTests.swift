import XCTest
@testable import OpenVoice

final class TypedSpeechPreviewTests: XCTestCase {
    func testCharacterWordAndSentenceChoices() {
        var settings = AppSettings()
        XCTAssertTrue(TypedSpeechPreview.previews(previous: "Hello", current: "Hello ", settings: settings).isEmpty)

        settings.speakTypedCharacters = true
        settings.speakTypedWords = true
        settings.speakTypedSentences = true
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hi", current: "Hi!", settings: settings),
                       ["exclamation mark", "Hi", "Hi!"])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hi!", current: "Hi! ", settings: settings), [])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "I don't", current: "I don't ", settings: settings),
                       ["don't"])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hi! Are you okay", current: "Hi! Are you okay?", settings: settings),
                       ["question mark", "okay", "Are you okay?"])
    }

    func testOnlySingleAppendedKeystrokesPreviewAndSpanishPunctuation() {
        var settings = AppSettings()
        settings.communicationLanguage = "es"
        settings.speakTypedCharacters = true
        settings.speakTypedWords = true
        settings.speakTypedSentences = true
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "¿Hola", current: "¿Hola?", settings: settings),
                       ["signo de interrogación", "Hola", "¿Hola?"])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hello", current: "Hello world", settings: settings), [])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hello", current: "Hell", settings: settings), [])
        XCTAssertEqual(TypedSpeechPreview.previews(previous: "Hello", current: "Hallo", settings: settings), [])
    }

    @MainActor
    func testSettingsDefaultOffForOldBackupsAndStayWithProfile() throws {
        let legacy = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(legacy.speakTypedCharacters)
        XCTAssertFalse(legacy.speakTypedWords)
        XCTAssertFalse(legacy.speakTypedSentences)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("voice.json")
        let source = CommunicationStore(storageURL: url)
        source.settings.speakTypedWords = true
        let firstID = source.activeProfileID
        XCTAssertTrue(source.addProfile("Other voice"))
        XCTAssertFalse(source.settings.speakTypedWords)
        XCTAssertTrue(source.switchProfile(to: firstID))
        XCTAssertTrue(source.settings.speakTypedWords)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restore.json"))
        try restored.importBackup(source.backupData())
        XCTAssertTrue(restored.settings.speakTypedWords)
    }

    @MainActor
    func testPreviewSpeechDoesNotSaveAHistoryEntry() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("voice.json"))
        source.settings.saveHistory = true
        source.settings.speakTypedWords = true
        source.previewTypedSpeech(previous: "I need help", current: "I need help ")
        XCTAssertTrue(source.history.isEmpty)
        source.stopSpeaking()
    }
}
