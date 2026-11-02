import XCTest
@testable import OpenVoice

final class SavedPhraseLanguageTests: XCTestCase {
    func testOlderPhraseDefaultsToCurrentVoiceAndCodesAreValidated() throws {
        let older = try JSONDecoder().decode(SavedPhrase.self,
            from: Data("{\"text\":\"Please wait.\"}".utf8))
        XCTAssertNil(older.languageCode)
        XCTAssertEqual(older.accessibleLabel, "Please wait.")
        XCTAssertEqual(PhraseLanguage.normalized(" zh-Hant-TW "), "zh-Hant-TW")
        XCTAssertNil(PhraseLanguage.normalized("not a language"))
        XCTAssertNil(PhraseLanguage.normalized("en--US"))
    }

    @MainActor
    func testPhraseLanguageStaysWithProfilesBackupsAndPhraseFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(store.addPhrase("Necesito agua.", folder: "Needs", languageCode: "es-ES"))
        XCTAssertFalse(store.addPhrase("Bad language", languageCode: "not a language"))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "Necesito agua." })
        XCTAssertEqual(phrase.languageCode, "es-ES")
        XCTAssertTrue(phrase.accessibleLabel.contains("es-ES"))

        let originalProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other"))
        XCTAssertFalse(store.phrases.contains { $0.id == phrase.id })
        XCTAssertTrue(store.switchProfile(to: originalProfile))
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first {
            $0.id == phrase.id
        }?.languageCode, "es-ES")

        let backup = CommunicationStore(storageURL: directory.appendingPathComponent("backup.json"))
        try backup.importBackup(store.backupData())
        XCTAssertEqual(backup.phrases.first { $0.id == phrase.id }?.languageCode, "es-ES")

        let data = try PhraseCollectionTransfer.exportData([phrase], named: "Spanish")
        let collection = try PhraseCollectionTransfer.importData(data)
        XCTAssertEqual(collection.phrases.first?.languageCode, "es-ES")
        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        XCTAssertEqual(recipient.importPhraseCollection(collection, mode: .addMissing).added, 1)
        XCTAssertEqual(recipient.phrases.first { $0.text == phrase.text }?.languageCode, "es-ES")
        let received = try XCTUnwrap(recipient.phrases.first { $0.text == phrase.text })
        XCTAssertTrue(recipient.updatePhraseLanguage(received, languageCode: nil))
        XCTAssertNil(recipient.phrases.first { $0.id == received.id }?.languageCode)
        XCTAssertEqual(recipient.importPhraseCollection(collection, mode: .updateMatching).updated, 1)
        XCTAssertEqual(recipient.phrases.first { $0.id == received.id }?.languageCode, "es-ES")
    }

    @MainActor
    func testInstalledLanguageSelectsADeviceVoice() throws {
        let code = try XCTUnwrap(PhraseLanguage.availableCodes.first)
        let store = CommunicationStore(storageURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("voice.json"))
        XCTAssertEqual(store.makeUtterance("Hello", language: code).voice?.language, code)
        store.appendCompletedPhrase("Bonjour", languageCode: code)
        XCTAssertEqual(store.messageSpeechSegments().last?.language, code)
    }
}
