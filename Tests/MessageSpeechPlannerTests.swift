import XCTest
@testable import OpenVoice

final class MessageSpeechPlannerTests: XCTestCase {
    func testLongMessageBuildsOneSegmentPerLanguageRun() {
        let words = Array(repeating: "communication", count: 2_000)
        let segments = MessageSpeechPlanner.segments(
            parts: words + ["agua", "please"],
            languages: Array(repeating: "en", count: words.count) + ["es", "en"],
            fallbackLanguage: "en")

        XCTAssertEqual(segments.map(\.language), ["en", "es", "en"])
        XCTAssertEqual(segments[0].text, words.joined(separator: " "))
        XCTAssertEqual(segments[1].text, "agua")
        XCTAssertEqual(segments[2].text, "please")
    }

    func testAdjacentWordsUseOneUtterancePerLanguageRun() {
        let segments = MessageSpeechPlanner.segments(
            parts: ["I", "want", "agua", "please", "  "],
            languages: ["en", "en", "es", "en", "es"], fallbackLanguage: "en")
        XCTAssertEqual(segments, [
            MessageSpeechSegment(text: "I want", language: "en"),
            MessageSpeechSegment(text: "agua", language: "es"),
            MessageSpeechSegment(text: "please", language: "en")
        ])
    }

    func testMissingLanguageUsesCurrentFallback() {
        let segments = MessageSpeechPlanner.segments(
            parts: ["hello", "mundo"], languages: ["en"], fallbackLanguage: "es")
        XCTAssertEqual(segments, [
            MessageSpeechSegment(text: "hello", language: "en"),
            MessageSpeechSegment(text: "mundo", language: "es")
        ])
    }

    func testAdjacentWordsSplitWhenFolderVoiceChanges() {
        let segments = MessageSpeechPlanner.segments(
            parts: ["I", "need", "water", "please"], languages: ["en", "en", "en", "en"],
            fallbackLanguage: "en", voiceIdentifiers: ["", "book.voice", "book.voice", ""])
        XCTAssertEqual(segments, [
            MessageSpeechSegment(text: "I", language: "en"),
            MessageSpeechSegment(text: "need water", language: "en", voiceIdentifier: "book.voice"),
            MessageSpeechSegment(text: "please", language: "en")
        ])
    }

    @MainActor
    func testFolderVoiceFollowsPictureWordsThroughRelaunchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: url)
        XCTAssertTrue(store.addBoardFolder("Needs book"))
        XCTAssertTrue(store.setBoardFolder("Needs book", for: "Needs"))
        XCTAssertTrue(store.setBoardFolderVoiceIdentifier("book.voice", for: "Needs book"))
        XCTAssertFalse(store.setBoardFolderVoiceIdentifier("other", for: "Missing"))
        let core = try XCTUnwrap(store.items.first { $0.category == "Core" && $0.label == "I" })
        let need = try XCTUnwrap(store.items.first { $0.category == "Needs" && $0.label == "water" })
        store.select(core)
        store.select(need)
        XCTAssertEqual(store.messageSpeechSegments().map(\.voiceIdentifier), ["", "book.voice"])
        XCTAssertNil(store.makeUtterance("water", language: "en", voiceIdentifier: "book.voice").voice,
                     "An unresolved folder voice must stay open for background speech selection")
        store.flushPersistence()

        let reopened = CommunicationStore(storageURL: url)
        XCTAssertEqual(reopened.messageSpeechSegments().map(\.voiceIdentifier), ["", "book.voice"])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(reopened.backupData())
        XCTAssertEqual(restored.messageSpeechSegments().map(\.voiceIdentifier), ["", "book.voice"])
        XCTAssertTrue(reopened.renameBoardFolder("Needs book", to: "Daily needs"))
        XCTAssertEqual(reopened.settings.boardFolderVoiceIdentifiers["Daily needs"], "book.voice")
        XCTAssertNil(reopened.settings.boardFolderVoiceIdentifiers["Needs book"])
        XCTAssertTrue(reopened.deleteBoardFolder("Daily needs"))
        XCTAssertTrue(reopened.settings.boardFolderVoiceIdentifiers.isEmpty)
        XCTAssertEqual(reopened.messageSpeechSegments().map(\.voiceIdentifier), [""])
    }

    @MainActor
    func testStoreKeepsSelectedLanguageThroughSwitchAndUndo() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        store.select(try XCTUnwrap(store.items.first(where: { $0.label == "I" })))
        store.settings.communicationLanguage = "es"
        store.select(try XCTUnwrap(store.items.first(where: { $0.label == "want" })))
        store.settings.communicationLanguage = "en"
        store.select(try XCTUnwrap(store.items.first(where: { $0.label == "water" })))
        XCTAssertEqual(store.composedMessage, "I quiero water")
        XCTAssertEqual(store.messageSpeechSegments(), [
            MessageSpeechSegment(text: "I", language: "en"),
            MessageSpeechSegment(text: "quiero", language: "es"),
            MessageSpeechSegment(text: "water", language: "en")
        ])

        store.settings.saveHistory = true
        store.speakMessage()
        XCTAssertEqual(store.history.first?.text, "I quiero water")
        XCTAssertEqual(store.history.count, 1)
        store.stopSpeaking()
        store.removeLast()
        XCTAssertEqual(store.messageSpeechSegments().count, 2)
        store.clearMessage()
        XCTAssertTrue(store.messageSpeechSegments().isEmpty)
    }
}
