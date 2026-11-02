import AVFoundation
import XCTest
@testable import OpenVoice

final class QuickResponseTests: XCTestCase {
    func testOlderSettingsKeepFourStarterRepliesAndExplicitlyEmptyListStaysEmpty() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings())) as? [String: Any])
        json.removeValue(forKey: "quickResponses")
        let older = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(older.quickResponses.map(\.text), ["yes", "no", "help", "break"])
        XCTAssertEqual(older.quickResponses.map(\.spanishText), ["sí", "no", "ayuda", "descanso"])

        json["quickResponses"] = []
        let hidden = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(hidden.quickResponses.isEmpty)
    }

    func testRepliesTrimDuplicatesAndLimitCountWithoutChangingOrder() {
        let replies = [QuickResponse(text: "  I need help  ", spanishText: "  Necesito ayuda  "),
                       QuickResponse(text: "i need HELP"),
                       QuickResponse(text: ""),
                       QuickResponse(text: "Stop"), QuickResponse(text: "Wait"),
                       QuickResponse(text: "More"), QuickResponse(text: "Finished"),
                       QuickResponse(text: "Please")]
        XCTAssertFalse(QuickResponse.canSave(replies))
        let cleaned = QuickResponse.cleaned(replies)
        XCTAssertEqual(cleaned.map(\.text), ["I need help", "Stop", "Wait", "More", "Finished", "Please"])
        XCTAssertEqual(cleaned[0].spanishText, "Necesito ayuda")
        XCTAssertEqual(cleaned[0].displayedText(language: "es"), "Necesito ayuda")
        XCTAssertEqual(cleaned[1].displayedText(language: "es"), "Stop")
        XCTAssertTrue(QuickResponse.canSave([]))
    }

    func testUntouchedStarterRepliesKeepTheirWordLinkAfterEditingAndMigration() {
        let starter = QuickResponse.starterReplies[0]
        XCTAssertEqual(starter.sourceWord, "yes")
        XCTAssertEqual(QuickResponse.cleaned([QuickResponse(text: "yes", spanishText: "sí")])[0].sourceWord,
                       "yes")
        var edited = starter
        edited.text = "Absolutely"
        XCTAssertNil(QuickResponse.cleaned([edited])[0].sourceWord)
        edited = starter
        edited.spanishText = "claro"
        XCTAssertNil(QuickResponse.cleaned([edited])[0].sourceWord)
    }

    func testOlderQuickReplyWithoutAudioStillDecodes() throws {
        let original = QuickResponse(text: "Please wait", spanishText: "Espera, por favor")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "audioData")
        json.removeValue(forKey: "action")
        let decoded = try JSONDecoder().decode(QuickResponse.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertNil(decoded.audioData)
        XCTAssertEqual(decoded.action, .addAndSpeak)
    }

    @MainActor
    func testRecordedQuickReplyStaysWithProfileAndBackupAndAddsMessage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstID = store.activeProfileID
        let recording = playableWAV()
        XCTAssertNotNil(try? AVAudioPlayer(data: recording))
        let reply = QuickResponse(text: "Please wait for me", spanishText: "Espérame, por favor",
                                  audioData: recording)
        store.settings.quickResponses = [reply]
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).settings.quickResponses.first?.audioData,
                       recording)
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.quickResponses.first?.audioData, recording)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.quickResponses.first?.audioData, recording)

        store.selectPhrase(CardPhrase(text: reply.text, spanishText: reply.spanishText),
                           audioData: recording)
        XCTAssertEqual(store.messageParts.last, reply.text)
    }

    private func playableWAV() -> Data {
        let header: [UInt8] = [
            0x52, 0x49, 0x46, 0x46, 0x64, 0x06, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x40, 0x1F, 0x00, 0x00, 0x80, 0x3E, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x40, 0x06, 0x00, 0x00
        ]
        return Data(header) + Data(repeating: 0, count: 1_600)
    }

    @MainActor
    func testStandaloneReplyKeepsBothDraftsAndSavesSpokenHistory() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("store.json"))
        store.settings.saveHistory = true
        store.selectPhrase(CardPhrase(text: "I need help"))
        store.typedMessage = "I am writing another message"
        let pictureDraft = store.messageParts

        store.speakStandaloneMessage("Please wait")
        XCTAssertEqual(store.messageParts, pictureDraft)
        XCTAssertEqual(store.typedMessage, "I am writing another message")
        XCTAssertEqual(store.history.first?.text, "Please wait")

        store.speakStandaloneMessage("Recorded interjection", audioData: playableWAV())
        XCTAssertEqual(store.messageParts, pictureDraft)
        XCTAssertEqual(store.typedMessage, "I am writing another message")
        XCTAssertEqual(store.history.first?.text, "Recorded interjection")
    }

    @MainActor
    func testEditedRepliesStayWithTheirProfileAcrossRelaunchAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstID = store.activeProfileID
        let custom = [QuickResponse(text: "I need a break", spanishText: "Necesito un descanso",
                                    action: .speakOnly),
                      QuickResponse(text: "Please wait")]
        store.settings.quickResponses = custom
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertEqual(store.settings.quickResponses.map(\.text), ["yes", "no", "help", "break"])
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.quickResponses, custom)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).settings.quickResponses, custom)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.quickResponses, custom)
    }
}
