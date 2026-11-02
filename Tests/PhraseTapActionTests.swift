import XCTest
@testable import OpenVoice

final class PhraseTapActionTests: XCTestCase {
    func testOlderSettingsDefaultToSpeakingPhrases() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings()))
                                 as? [String: Any])
        json.removeValue(forKey: "phraseTapAction")
        let older = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(older.phraseTapAction, .speak)
    }

    func testOlderPhraseFollowsProfileTapAction() throws {
        let older = try JSONDecoder().decode(SavedPhrase.self,
            from: Data("{\"text\":\"Please wait.\"}".utf8))
        XCTAssertNil(older.tapActionOverride)
        XCTAssertEqual(older.effectiveTapAction(fallback: .speak), .speak)
        XCTAssertEqual(older.effectiveTapAction(fallback: .insertTyped), .insertTyped)
    }

    @MainActor
    func testPhraseTapActionStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        let firstID = store.activeProfileID
        store.settings.phraseTapAction = .insertTyped
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).settings.phraseTapAction, .insertTyped)

        XCTAssertTrue(store.addProfile("Other"))
        XCTAssertEqual(store.settings.phraseTapAction, .speak)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.phraseTapAction, .insertTyped)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.settings.phraseTapAction, .insertTyped)
    }

    @MainActor
    func testInsertionAppendsToTypedDraftWithoutSpeechOrPictureChanges() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        store.settings.saveHistory = true
        store.appendCompletedPhrase("picture draft")
        store.typedMessage = "I need"
        let historyCount = store.history.count

        XCTAssertTrue(store.appendTypedPhrase("  a quiet place.  "))
        XCTAssertEqual(store.typedMessage, "I need a quiet place.")
        XCTAssertEqual(store.composedMessage, "picture draft")
        XCTAssertEqual(store.history.count, historyCount)
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).typedMessage, store.typedMessage)

        store.typedMessage += "\n"
        XCTAssertTrue(store.appendTypedPhrase("Please wait"))
        XCTAssertEqual(store.typedMessage, "I need a quiet place.\nPlease wait")
        XCTAssertFalse(store.appendTypedPhrase("  "))
    }

    @MainActor
    func testPhraseOverrideSurvivesProfileBackupAndFileExchange() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: sourceURL)
        XCTAssertTrue(store.addPhrase("I have more to say.", tapActionOverride: .insertTyped))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "I have more to say." })
        XCTAssertEqual(phrase.effectiveTapAction(fallback: .speak), .insertTyped)

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other"))
        XCTAssertFalse(store.phrases.contains { $0.id == phrase.id })
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).phrases.first {
            $0.id == phrase.id
        }?.tapActionOverride, .insertTyped)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("backup.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.tapActionOverride, .insertTyped)

        let collection = try PhraseCollectionTransfer.importData(
            PhraseCollectionTransfer.exportData([phrase], named: "Shared"))
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        XCTAssertEqual(target.importPhraseCollection(collection, mode: .addMissing).added, 1)
        let received = try XCTUnwrap(target.phrases.first { $0.text == phrase.text })
        XCTAssertEqual(received.tapActionOverride, .insertTyped)
        XCTAssertTrue(target.updatePhraseTapAction(received, override: .speak))
        XCTAssertEqual(target.phrases.first { $0.id == received.id }?
            .effectiveTapAction(fallback: .insertTyped), .speak)
        XCTAssertEqual(target.importPhraseCollection(collection, mode: .updateMatching).updated, 1)
        XCTAssertEqual(target.phrases.first { $0.id == received.id }?.tapActionOverride, .insertTyped)
        XCTAssertTrue(target.updatePhraseTapAction(received, override: nil))
        XCTAssertEqual(target.phrases.first { $0.id == received.id }?
            .effectiveTapAction(fallback: .speak), .speak)
    }
}
