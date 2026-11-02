import XCTest
@testable import OpenVoice

final class MessageSpeechPlannerTests: XCTestCase {
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
