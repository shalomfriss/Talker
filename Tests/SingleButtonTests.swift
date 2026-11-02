import XCTest
@testable import OpenVoice

final class SingleButtonTests: XCTestCase {
    func testOlderSettingsDecodeWithoutSingleButtonOptions() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertNil(settings.singleButtonPhraseID)
        XCTAssertFalse(settings.singleButtonLocked)
    }

    @MainActor
    func testSelectedPhraseAndLockStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(source.addPhrase("Please wait for me."))
        let phrase = try XCTUnwrap(source.phrases.first { $0.text == "Please wait for me." })
        source.selectSingleButtonPhrase(phrase)
        source.settings.singleButtonLocked = true

        let reopened = CommunicationStore(storageURL: sourceURL)
        XCTAssertEqual(reopened.singleButtonPhrase?.id, phrase.id)
        XCTAssertTrue(reopened.settings.singleButtonLocked)

        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second communicator"))
        XCTAssertNil(source.singleButtonPhrase)
        XCTAssertFalse(source.settings.singleButtonLocked)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.singleButtonPhrase?.id, phrase.id)
        XCTAssertTrue(source.settings.singleButtonLocked)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.singleButtonPhrase?.text, phrase.text)
        XCTAssertTrue(restored.settings.singleButtonLocked)

        XCTAssertTrue(source.updatePhraseText(phrase, to: "Please wait for {person}."))
        XCTAssertNil(source.singleButtonPhrase)
        XCTAssertNil(source.settings.singleButtonPhraseID)

        source.selectSingleButtonPhrase(phrase)
        XCTAssertNil(source.settings.singleButtonPhraseID)

        source.deletePhrase(phrase)
        XCTAssertNil(source.singleButtonPhrase)
        XCTAssertNil(source.settings.singleButtonPhraseID)
    }
}
