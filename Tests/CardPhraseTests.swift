import XCTest
@testable import OpenVoice

final class CardPhraseTests: XCTestCase {
    func testOldButtonsDecodeWithoutPhraseChoices() throws {
        let item = CommunicationItem(label: "music", symbol: "🎵", message: "music", category: "Activities")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        object.removeValue(forKey: "phraseOptions")
        let restored = try JSONDecoder().decode(CommunicationItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.phraseOptions)
        XCTAssertEqual(restored.label, "music")
    }

    func testPhraseChoicesCleanDuplicatesAndResolveLanguage() {
        let choices = CardPhrase.cleaned([
            CardPhrase(text: "  Please change the music.  ", spanishText: "  Cambia la música, por favor.  "),
            CardPhrase(text: "please change the music."),
            CardPhrase(text: "   ")
        ])
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(choices[0].resolved(for: "es").text, "Cambia la música, por favor.")
        XCTAssertEqual(choices[0].resolved(for: "es").language, "es")
        XCTAssertEqual(CardPhrase(text: "Hello").resolved(for: "es").language, "en")
    }

    @MainActor
    func testCardChoicesStayWithProfileBackupAndComposeInSelectedLanguage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        let firstProfile = source.activeProfileID
        source.addItem(label: "my music", symbol: "🎵", message: "music", category: "Activities",
                       imageData: nil, phraseOptions: [CardPhrase(text: "I want music.", spanishText: "Quiero música.")])
        let item = try XCTUnwrap(source.items.first { $0.label == "my music" })
        let phrase = try XCTUnwrap(item.phraseOptions?.first)
        source.settings.communicationLanguage = "es"
        source.settings.saveHistory = true
        source.selectPhrase(phrase)
        XCTAssertEqual(source.messageParts, ["Quiero música."])
        XCTAssertEqual(source.messageSpeechSegments(), [MessageSpeechSegment(text: "Quiero música.", language: "es")])
        XCTAssertEqual(source.history.first?.text, "Quiero música.")

        source.settings.communicationLanguage = "en"
        source.selectPhrase(phrase)
        XCTAssertEqual(source.messageParts, ["Quiero música.", "I want music."])
        XCTAssertEqual(source.messageSpeechSegments().map(\.language), ["es", "en"])
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertFalse(source.items.contains { $0.label == "my music" })
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.items.first { $0.id == item.id }?.phraseOptions, [phrase])
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).items.first { $0.id == item.id }?.phraseOptions, [phrase])

        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try target.importBackup(source.backupData())
        XCTAssertEqual(target.items.first { $0.id == item.id }?.phraseOptions, [phrase])
        XCTAssertEqual(target.messageSpeechSegments().map(\.language), ["es", "en"])
    }
}
