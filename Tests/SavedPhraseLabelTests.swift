import XCTest
@testable import OpenVoice

final class SavedPhraseLabelTests: XCTestCase {
    func testOlderPhraseAndConversationDecodeWithNormalJoining() throws {
        let phrase = try JSONDecoder().decode(SavedPhrase.self,
            from: Data("{\"text\":\"kind\"}".utf8))
        XCTAssertEqual(phrase.joinBehavior, .normal)
        let draft = try JSONDecoder().decode(ConversationDraft.self,
            from: Data("{\"name\":\"Old\",\"typedMessage\":\"hello\"}".utf8))
        XCTAssertNil(draft.pendingPhrasePrefix)
    }

    @MainActor
    func testPrefixAndSuffixJoiningSurvivesDraftSwitchAndPhraseTransfer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addPhrase("un", tapActionOverride: .insertTyped, joinBehavior: .prefix))
        XCTAssertTrue(store.addPhrase("kind", tapActionOverride: .insertTyped))
        XCTAssertTrue(store.addPhrase("ness", tapActionOverride: .insertTyped, joinBehavior: .suffix))
        let prefix = try XCTUnwrap(store.phrases.first { $0.text == "un" })
        let base = try XCTUnwrap(store.phrases.first { $0.text == "kind" })
        let suffix = try XCTUnwrap(store.phrases.first { $0.text == "ness" })

        XCTAssertTrue(store.appendTypedPhrase("Please"))
        XCTAssertTrue(store.appendTypedPhrase(prefix))
        XCTAssertEqual(store.typedMessage, "Please un")
        let firstDraftID = store.activeConversationID
        XCTAssertTrue(store.addConversation("Second"))
        XCTAssertTrue(store.switchConversation(to: firstDraftID))
        XCTAssertTrue(store.appendTypedPhrase(base))
        XCTAssertTrue(store.appendTypedPhrase(suffix))
        XCTAssertEqual(store.typedMessage, "Please unkindness")

        store.typedMessage = ""
        XCTAssertTrue(store.appendTypedPhrase(prefix))
        let reopened = CommunicationStore(storageURL: file)
        XCTAssertTrue(reopened.appendTypedPhrase(base))
        XCTAssertEqual(reopened.typedMessage, "unkind")

        let data = try PhraseCollectionTransfer.exportData(store.phrases, named: "Word parts")
        let imported = try PhraseCollectionTransfer.importData(data)
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        let result = target.importPhraseCollection(imported, mode: .addMissing)
        XCTAssertEqual(result.added, 3)
        XCTAssertEqual(target.phrases.first { $0.text == "un" }?.joinBehavior, .prefix)
        XCTAssertEqual(target.phrases.first { $0.text == "ness" }?.joinBehavior, .suffix)
    }

    func testOlderPhraseUsesFullTextAsItsCardLabel() throws {
        let phrase = try JSONDecoder().decode(SavedPhrase.self,
            from: Data("{\"text\":\"Please give me time to answer.\"}".utf8))
        XCTAssertNil(phrase.label)
        XCTAssertEqual(phrase.displayLabel, phrase.text)
        XCTAssertEqual(phrase.accessibleLabel, phrase.text)
    }

    @MainActor
    func testShortLabelKeepsSpokenTextAndRecordingAcrossBackupAndProfiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addPhrase("I need a quiet place.", folder: "Needs", label: "  🧘 Quiet  "))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "I need a quiet place." })
        XCTAssertEqual(phrase.label, "🧘 Quiet")
        XCTAssertEqual(phrase.displayLabel, "🧘 Quiet")
        XCTAssertEqual(phrase.accessibleLabel, "🧘 Quiet. Full phrase: I need a quiet place.")
        let recording = Data([1, 2, 3, 4])
        store.updatePhraseRecording(phrase, audioData: recording)
        XCTAssertTrue(store.updatePhraseDetails(phrase, text: phrase.text, shortcut: nil,
                                                label: "  My quiet space  "))
        let updated = try XCTUnwrap(store.phrases.first { $0.id == phrase.id })
        XCTAssertEqual(updated.text, phrase.text)
        XCTAssertEqual(updated.label, "My quiet space")
        XCTAssertEqual(updated.audioData, recording)
        XCTAssertFalse(store.updatePhraseDetails(updated, text: updated.text, shortcut: nil,
                                                 label: String(repeating: "a", count: 41)))
        XCTAssertEqual(store.phrases.first { $0.id == phrase.id }?.label, "My quiet space")

        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertFalse(store.phrases.contains { $0.id == phrase.id })
        XCTAssertTrue(store.switchProfile(to: profileID))
        let reopened = CommunicationStore(storageURL: file)
        XCTAssertEqual(reopened.phrases.first { $0.id == phrase.id }?.label, "My quiet space")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.label, "My quiet space")
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.text, phrase.text)
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.audioData, recording)

        XCTAssertTrue(store.updatePhraseDetails(updated, text: phrase.text, shortcut: nil, label: " "))
        XCTAssertNil(store.phrases.first { $0.id == phrase.id }?.label)
        XCTAssertEqual(store.phrases.first { $0.id == phrase.id }?.displayLabel, phrase.text)
    }
}
