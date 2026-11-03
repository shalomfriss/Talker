import XCTest
@testable import OpenVoice

final class LearnedPredictionTests: XCTestCase {
    func testDenseLearnedVocabularyKeepsSuggestionsAndSentenceCompletion() {
        var model = LearnedPredictionModel()
        model.learn("I need quiet", language: "en")
        model.learn("I need quiet", language: "en")
        for number in 0..<300 {
            let first = Character(UnicodeScalar(97 + number / 26)!)
            let second = Character(UnicodeScalar(97 + number % 26)!)
            model.learn("Please choose \(first)\(second)", language: "en")
        }

        XCTAssertGreaterThan(model.entries.count, 800)
        XCTAssertEqual(model.suggestions(for: "I need ", language: "en", limit: 5), ["quiet"])
        XCTAssertEqual(model.sentenceCompletions(for: "I ne", language: "en", limit: 4),
                       ["I need quiet"])
    }

    func testRepeatedSpeechLearnsContextAndKeepsLanguagesSeparate() {
        var model = LearnedPredictionModel()
        model.learn("I need quiet. I need water", language: "en")
        XCTAssertTrue(model.suggestions(for: "I need ", language: "en", limit: 5).isEmpty)
        model.learn("I need quiet", language: "en")
        XCTAssertEqual(model.suggestions(for: "I need ", language: "en", limit: 5), ["quiet"])
        XCTAssertEqual(model.suggestions(for: "qui", language: "en", limit: 5), ["quiet"])
        XCTAssertTrue(model.suggestions(for: "I need ", language: "es", limit: 5).isEmpty)
        XCTAssertTrue(model.suggestions(for: "quiet. ", language: "en", limit: 5).isEmpty)
        model.learn("Necesito agua", language: "es")
        model.learn("Necesito agua", language: "es")
        XCTAssertEqual(model.suggestions(for: "Necesito ", language: "es", limit: 5), ["agua"])
    }

    func testLearnedWordsJoinOrdinarySuggestionsOnlyWhenSupplied() {
        var model = LearnedPredictionModel()
        model.learn("I need quiet", language: "en")
        model.learn("I need quiet", language: "en")
        let without = WordPrediction.suggestions(for: "I need ", items: [], phrases: [])
        let with = WordPrediction.suggestions(for: "I need ", items: [], phrases: [], learned: model)
        XCTAssertTrue(without.isEmpty)
        XCTAssertEqual(with, ["quiet"])
        model.clear()
        XCTAssertTrue(model.entries.isEmpty)
        XCTAssertTrue(WordPrediction.suggestions(for: "I need ", items: [], phrases: [], learned: model).isEmpty)
    }

    func testRepeatedPatternsCompleteSentencesWithoutSavingWholeMessages() {
        var model = LearnedPredictionModel()
        model.learn("I need quiet. Please wait", language: "en")
        XCTAssertTrue(model.sentenceCompletions(for: "I ne", language: "en", limit: 4).isEmpty)
        model.learn("I need quiet. Please wait", language: "en")
        XCTAssertEqual(model.sentenceCompletions(for: "I ne", language: "en", limit: 4),
                       ["I need quiet"])
        XCTAssertEqual(model.sentenceCompletions(for: "Please w", language: "en", limit: 4),
                       ["Please wait"])
        XCTAssertTrue(model.sentenceCompletions(for: "I ne", language: "es", limit: 4).isEmpty)
        XCTAssertFalse(model.entries.contains { $0.word == "I need quiet" })
        XCTAssertFalse(model.suggestions(for: "I need quiet ", language: "en", limit: 5)
            .contains("<sentence-end>"))
        XCTAssertEqual(SentencePrediction.suggestions(for: "Hello. I ne", phrases: [], learned: model),
                       ["I need quiet"])
        XCTAssertEqual(SentencePrediction.completing("Hello. I ne", with: "I need quiet"),
                       "Hello. I need quiet")
        XCTAssertTrue(SentencePrediction.suggestions(for: "I ne", phrases: []).isEmpty)
        model.clear()
        XCTAssertTrue(model.sentenceCompletions(for: "I ne", language: "en", limit: 4).isEmpty)
    }

    @MainActor
    func testOptInLearningPersistsPerProfileAndBackupWithoutHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("learned.json")
        let store = CommunicationStore(storageURL: file)
        store.speakStandaloneMessage("I need quiet")
        XCTAssertTrue(store.learnedPrediction.entries.isEmpty)
        store.settings.learnPrediction = true
        store.speakStandaloneMessage("I need quiet")
        store.speakStandaloneMessage("I need quiet")
        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.learnedPrediction.suggestions(for: "I need ", language: "en", limit: 5), ["quiet"])
        let learned = store.learnedPrediction
        store.settings.learnPrediction = false
        store.speakStandaloneMessage("I need water")
        XCTAssertEqual(store.learnedPrediction, learned)
        store.settings.learnPrediction = true
        store.settings.historyPaused = true
        store.speakStandaloneMessage("I need water")
        XCTAssertEqual(store.learnedPrediction, learned)
        let backup = try store.backupData()
        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertTrue(store.learnedPrediction.entries.isEmpty)
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.learnedPrediction, learned)
        XCTAssertEqual(CommunicationStore(storageURL: file).learnedPrediction, learned)
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(backup)
        XCTAssertEqual(imported.learnedPrediction, learned)
        imported.clearLearnedPrediction()
        XCTAssertTrue(imported.learnedPrediction.entries.isEmpty)
    }

    func testOlderDataDecodesWithLearningOffAndNoPatterns() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "learnedPrediction")
        var settings = try XCTUnwrap(object["settings"] as? [String: Any])
        settings.removeValue(forKey: "learnPrediction")
        object["settings"] = settings
        let decoded = try JSONDecoder().decode(StoredData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.settings.learnPrediction)
        XCTAssertTrue(decoded.learnedPrediction.entries.isEmpty)
    }
}
