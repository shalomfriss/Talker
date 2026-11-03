import XCTest
@testable import OpenVoice

final class ConversationDraftTests: XCTestCase {
    @MainActor
    func testUnchangedDraftDoesNotSaveAndPendingTypedDraftFlushesOnce() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let initialWrites = store.persistenceWriteCount

        store.flushConversationDraft()
        XCTAssertEqual(store.persistenceWriteCount, initialWrites)

        store.typedMessage = "I need a break"
        XCTAssertEqual(store.persistenceWriteCount, initialWrites)
        store.flushConversationDraft()
        XCTAssertEqual(store.persistenceWriteCount, initialWrites + 1)
        store.flushConversationDraft()
        XCTAssertEqual(store.persistenceWriteCount, initialWrites + 1)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.typedMessage, "I need a break")
    }

    func testOldBackupGetsOneEmptyConversation() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "conversations")
        object.removeValue(forKey: "activeConversationID")
        let restored = try JSONDecoder().decode(StoredData.self,
                                                 from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(restored.conversations.count, 1)
        XCTAssertEqual(restored.activeConversationID, restored.conversations[0].id)
        XCTAssertEqual(restored.conversations[0].preview, "Empty conversation")
        XCTAssertNil(restored.conversations[0].clearOnNextSelection)
    }

    @MainActor
    func testAutoClearWaitsForTheNextSelectionAndStaysWithTheConversation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let yes = try XCTUnwrap(store.items.first { $0.label == "yes" })
        let no = try XCTUnwrap(store.items.first { $0.label == "no" })
        let firstConversation = store.activeConversationID
        store.settings.autoClearAfterSpeaking = true
        store.select(yes)
        store.select(no)
        XCTAssertEqual(store.composedMessage, "yes no")
        store.speakMessage()
        store.stopSpeaking()
        XCTAssertEqual(store.composedMessage, "yes no")
        XCTAssertTrue(store.conversations[0].clearOnNextSelection == true)

        XCTAssertTrue(store.addConversation("At school"))
        store.select(no)
        XCTAssertEqual(store.composedMessage, "no")
        XCTAssertTrue(store.switchConversation(to: firstConversation))
        XCTAssertEqual(store.composedMessage, "yes no")

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertTrue(relaunched.settings.autoClearAfterSpeaking)
        XCTAssertEqual(relaunched.composedMessage, "yes no")
        relaunched.select(yes)
        XCTAssertEqual(relaunched.composedMessage, "yes")

        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.composedMessage, "yes no")
        restored.appendCompletedPhrase("help me")
        XCTAssertEqual(restored.composedMessage, "help me")

        restored.select(yes)
        restored.speakMessage()
        restored.stopSpeaking()
        restored.removeLast()
        restored.select(no)
        XCTAssertEqual(restored.composedMessage, "help me no")
        restored.speakMessage()
        restored.stopSpeaking()
        restored.selectPhrase(CardPhrase(text: "a break"))
        restored.stopSpeaking()
        XCTAssertEqual(restored.composedMessage, "a break")
        restored.speakMessage()
        restored.stopSpeaking()
        restored.settings.autoClearAfterSpeaking = false
        restored.select(yes)
        XCTAssertEqual(restored.composedMessage, "a break yes")
    }

    @MainActor
    func testSwitchingConversationsPreservesBothDraftTypesAndSpeechLanguage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeConversationID
        let yes = try XCTUnwrap(store.items.first(where: { $0.label == "yes" }))
        store.settings.communicationLanguage = "es"
        store.select(yes)
        store.typedMessage = "A longer answer in progress"
        XCTAssertEqual(store.messagePartLanguages, ["es"])

        XCTAssertTrue(store.addConversation("Quick reply"))
        let secondID = store.activeConversationID
        XCTAssertNotEqual(secondID, firstID)
        XCTAssertTrue(store.messageParts.isEmpty)
        XCTAssertTrue(store.typedMessage.isEmpty)
        store.settings.communicationLanguage = "en"
        store.select(yes)
        store.typedMessage = "Second typed answer"

        XCTAssertTrue(store.switchConversation(to: firstID))
        XCTAssertEqual(store.messagePartLanguages, ["es"])
        XCTAssertEqual(store.messageParts.count, 1)
        XCTAssertEqual(store.typedMessage, "A longer answer in progress")
        XCTAssertEqual(store.messageSpeechSegments().first?.language, "es")
        XCTAssertTrue(store.switchConversation(to: secondID))
        XCTAssertEqual(store.typedMessage, "Second typed answer")

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.activeConversationID, secondID)
        XCTAssertEqual(relaunched.typedMessage, "Second typed answer")
        XCTAssertTrue(relaunched.switchConversation(to: firstID))
        XCTAssertEqual(relaunched.typedMessage, "A longer answer in progress")
        XCTAssertEqual(relaunched.messageSpeechSegments().first?.language, "es")
    }

    @MainActor
    func testConversationsStayWithProfileAndBackupAndCanBeManaged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstProfile = source.activeProfileID
        XCTAssertTrue(source.addConversation("At school"))
        let schoolID = source.activeConversationID
        source.typedMessage = "I need a break."
        XCTAssertFalse(source.addConversation("at SCHOOL"))
        XCTAssertTrue(source.renameConversation(id: schoolID, to: "Classroom"))
        XCTAssertFalse(source.renameConversation(id: schoolID, to: "Conversation 1"))

        let backup = try source.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.activeConversationName, "Classroom")
        XCTAssertEqual(restored.typedMessage, "I need a break.")
        XCTAssertEqual(restored.conversations.count, 2)

        XCTAssertTrue(source.addProfile("Second person"))
        XCTAssertEqual(source.conversations.count, 1)
        XCTAssertTrue(source.typedMessage.isEmpty)
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.activeConversationName, "Classroom")
        XCTAssertEqual(source.typedMessage, "I need a break.")

        XCTAssertTrue(source.deleteConversation(id: schoolID))
        XCTAssertEqual(source.conversations.count, 1)
        XCTAssertNotEqual(source.activeConversationID, schoolID)
        XCTAssertFalse(source.deleteConversation(id: source.activeConversationID))
    }

    @MainActor
    func testPrivateConversationDiscardsDraftAndDoesNotTrainOrSaveHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let yes = try XCTUnwrap(store.items.first { $0.label == "yes" })
        let no = try XCTUnwrap(store.items.first { $0.label == "no" })
        store.settings.recentPictureWordsEnabled = true
        store.settings.recentPhrasesEnabled = true
        store.settings.learnPrediction = true
        store.settings.autoClearAfterSpeaking = true
        store.setNearbyChatSavingEnabled(true)
        store.select(yes)
        store.typedMessage = "Saved typed draft"
        let savedHistory = store.history
        let savedLearning = store.learnedPrediction
        let savedRecents = store.settings.recentPictureWordIDs
        let savedRecentPhrases = store.settings.recentPhraseIDs

        store.beginPrivateConversation()
        XCTAssertTrue(store.isPrivateConversationActive)
        XCTAssertEqual(store.activeConversationName, "Private conversation")
        XCTAssertTrue(store.messageParts.isEmpty)
        XCTAssertTrue(store.typedMessage.isEmpty)
        store.select(no)
        store.typedMessage = "A private typed message"
        store.speakMessage()
        store.stopSpeaking()
        store.select(yes)
        XCTAssertEqual(store.composedMessage, "yes")
        store.clearMessage()
        XCTAssertTrue(store.canUndoClearMessage)
        store.undoClearMessage()
        XCTAssertEqual(store.composedMessage, "yes")
        store.speak(store.typedMessage, saveToHistory: true, followAlong: .typed)
        store.stopSpeaking()
        if let phrase = store.phrases.first { store.recordRecentPhrase(phrase) }
        store.appendNearbyMessage(NearbyChatMessage(peerName: "Partner", isMine: true,
                                                    text: "Private nearby message"))
        store.flushConversationDraft()
        store.flushPersistence()

        XCTAssertEqual(store.history, savedHistory)
        XCTAssertEqual(store.learnedPrediction, savedLearning)
        XCTAssertEqual(store.settings.recentPictureWordIDs, savedRecents)
        XCTAssertEqual(store.settings.recentPhraseIDs, savedRecentPhrases)
        XCTAssertTrue(store.nearbyMessages.isEmpty)
        XCTAssertEqual(store.conversations.count, 1)
        XCTAssertEqual(store.conversations[0].typedMessage, "Saved typed draft")
        XCTAssertEqual(store.conversations[0].messageParts, ["yes"])
        XCTAssertNil(store.conversations[0].clearedPictureMessage)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertFalse(relaunched.isPrivateConversationActive)
        XCTAssertEqual(relaunched.typedMessage, "Saved typed draft")
        XCTAssertEqual(relaunched.composedMessage, "yes")
        let backup = try JSONDecoder().decode(StoredData.self, from: store.backupData())
        XCTAssertEqual(backup.conversations[0].typedMessage, "Saved typed draft")
        XCTAssertEqual(backup.conversations[0].messageParts, ["yes"])

        store.endPrivateConversation()
        XCTAssertFalse(store.isPrivateConversationActive)
        XCTAssertEqual(store.typedMessage, "Saved typed draft")
        XCTAssertEqual(store.composedMessage, "yes")
        XCTAssertFalse(store.canUndoClearMessage)
    }

    @MainActor
    func testSwitchingSavedConversationDiscardsPrivateSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstID = store.activeConversationID
        XCTAssertTrue(store.addConversation("School"))
        store.typedMessage = "School message"
        store.beginPrivateConversation()
        store.typedMessage = "Private message"
        XCTAssertTrue(store.switchConversation(to: firstID))
        XCTAssertFalse(store.isPrivateConversationActive)
        XCTAssertTrue(store.typedMessage.isEmpty)
        XCTAssertTrue(store.switchConversation(to: store.conversations.first { $0.name == "School" }!.id))
        XCTAssertEqual(store.typedMessage, "School message")
    }
}
