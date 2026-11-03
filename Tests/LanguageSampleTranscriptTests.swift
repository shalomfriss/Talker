import XCTest
@testable import OpenVoice

final class LanguageSampleTranscriptTests: XCTestCase {
    func testCSVExportOrdersTurnsAndEscapesUserText() {
        let earlier = SpokenMessage(text: "I said, \"wait\"\nnow", date: Date(timeIntervalSince1970: 100),
                                    speaker: .communicator, inputMode: .typed)
        let later = SpokenMessage(text: "=2+2", date: Date(timeIntervalSince1970: 120),
                                  speaker: .partner, inputMode: .manualNote)
        let csv = LanguageSampleTranscript.renderCSV(entries: [later, earlier], profileName: "Alex, Jr")

        XCTAssertTrue(csv.hasPrefix("timestamp_utc,profile,speaker,input_mode,message\n"))
        XCTAssertTrue(csv.contains("\"1970-01-01T00:01:40.000Z\",\"Alex, Jr\",\"Communicator\",\"Typed\",\"I said, \"\"wait\"\"\nnow\""))
        XCTAssertTrue(csv.contains("\"1970-01-01T00:02:00.000Z\",\"Alex, Jr\",\"Partner\",\"Manually entered\",\"'=2+2\""))
        XCTAssertLessThan(csv.range(of: "00:01:40")!.lowerBound, csv.range(of: "00:02:00")!.lowerBound)
    }

    func testLegacySavedMessageDoesNotGainInventedSpeakerOrInputMode() throws {
        let original = SpokenMessage(text: "I need time")
        let decoded = try JSONDecoder().decode(SpokenMessage.self, from: JSONEncoder().encode(original))
        XCTAssertNil(decoded.speaker)
        XCTAssertNil(decoded.inputMode)
        let text = LanguageSampleTranscript.render(entries: [decoded], profileName: "My Voice",
                                                   timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(text.contains("Speaker not recorded (Input not recorded): I need time"))
    }

    func testTranscriptOrdersTurnsAndLabelsManualPartnerEntry() {
        let earlier = SpokenMessage(text: "I need help\nnow", date: Date(timeIntervalSince1970: 100),
                                    speaker: .communicator, inputMode: .picture)
        let later = SpokenMessage(text: "What would help?", date: Date(timeIntervalSince1970: 120),
                                  speaker: .partner, inputMode: .manualNote)
        let text = LanguageSampleTranscript.render(entries: [later, earlier], profileName: "Alex",
                                                   timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(text.contains("Communicator (Picture board): I need help now"))
        XCTAssertTrue(text.contains("Partner (Manually entered): What would help?"))
        XCTAssertLessThan(text.range(of: "I need help now")!.lowerBound,
                          text.range(of: "What would help?")!.lowerBound)
        XCTAssertTrue(text.contains("Saved entries: 2"))
    }

    func testPartnerTurnsStayOutOfPredictionAndCommunicatorInsights() {
        let now = Date()
        let partner = SpokenMessage(text: "I want zebra cakes", date: now,
                                    speaker: .partner, inputMode: .manualNote)
        let communicator = SpokenMessage(text: "I want water", date: now,
                                         speaker: .communicator, inputMode: .typed)
        XCTAssertEqual(WordPrediction.suggestions(for: "zeb", items: [], phrases: [],
                                                  history: [partner]), [])
        XCTAssertEqual(SentencePrediction.suggestions(for: "I want z", phrases: [],
                                                      history: [partner]), [])
        let insights = SavedMessageInsights(history: [partner, communicator], now: now)
        XCTAssertEqual(insights.total, 1)
        XCTAssertEqual(insights.repeatedMessages.count, 0)
    }

    @MainActor
    func testPartnerTurnRequiresHistoryAndDoesNotEnterPrivateConversation() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: url)
        XCTAssertFalse(store.addPartnerTurn("Hello"))
        store.settings.saveHistory = true
        XCTAssertTrue(store.addPartnerTurn(" What would help? "))
        XCTAssertEqual(store.history.first?.text, "What would help?")
        XCTAssertEqual(store.history.first?.speaker, .partner)
        XCTAssertEqual(store.history.first?.inputMode, .manualNote)
        store.settings.historyPaused = true
        XCTAssertFalse(store.addPartnerTurn("Paused"))
        store.settings.historyPaused = false
        store.beginPrivateConversation()
        XCTAssertFalse(store.addPartnerTurn("Private"))
        store.endPrivateConversation()
        store.flushPersistence()
        let relaunched = CommunicationStore(storageURL: url)
        XCTAssertEqual(relaunched.history.count, 1)
        XCTAssertEqual(relaunched.history.first?.speaker, .partner)
    }

    @MainActor
    func testTypedSpeechRecordsItsInputModeWhenHistoryIsEnabled() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        store.settings.saveHistory = true
        store.speak("I want water", saveToHistory: true, followAlong: .typed)
        XCTAssertEqual(store.history.first?.speaker, .communicator)
        XCTAssertEqual(store.history.first?.inputMode, .typed)
        store.stopSpeaking()
    }
}
