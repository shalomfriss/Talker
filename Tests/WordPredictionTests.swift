import XCTest
@testable import OpenVoice

final class WordPredictionTests: XCTestCase {
    func testCoreWordsAreSuggestedBeforeOtherVocabulary() {
        let results = WordPrediction.suggestions(for: "I wa", items: StarterVocabulary.items,
                                                  phrases: StarterVocabulary.phrases)
        XCTAssertEqual(results.first, "want")
        XCTAssertTrue(results.contains("water"))
    }

    func testSelectionCompletesOnlyTheCurrentWord() {
        XCTAssertEqual(WordPrediction.completing("I wa", with: "want"), "I want ")
        XCTAssertEqual(WordPrediction.completing("Hello, wa", with: "water"), "Hello, water ")
    }

    func testSavedPhrasesAndCardPhrasesSuggestTheNextWord() {
        let suggestions = WordPrediction.suggestions(for: "I need ", items: StarterVocabulary.items,
                                                      phrases: StarterVocabulary.phrases)
        XCTAssertTrue(suggestions.contains("a"))
        XCTAssertEqual(WordPrediction.completing("I need ", with: "a"), "I need a ")

        let cardSuggestions = WordPrediction.suggestions(for: "I want ", items: StarterVocabulary.items,
                                                          phrases: [])
        XCTAssertTrue(cardSuggestions.contains("something"))
    }

    func testTwoWordContextRanksRelevantContinuationFirst() {
        let phrases = [SavedPhrase(text: "You want pizza"), SavedPhrase(text: "I want water")]
        let suggestions = WordPrediction.suggestions(for: "I want ", items: [], phrases: phrases)
        XCTAssertEqual(suggestions.first, "water")
        XCTAssertTrue(suggestions.contains("pizza"))
    }

    func testRecentMessagesContributeOnlyWhenProvided() {
        let history = [SpokenMessage(text: "I need quiet"), SpokenMessage(text: "I need quiet")]
        let withoutHistory = WordPrediction.suggestions(for: "I need ", items: [], phrases: [])
        let withHistory = WordPrediction.suggestions(for: "I need ", items: [], phrases: [], history: history)
        XCTAssertTrue(withoutHistory.isEmpty)
        XCTAssertEqual(withHistory.first, "quiet")
    }

    func testSpanishWordsWorkAndTemplatesDoNotLeakBlankNames() {
        let phrases = [SavedPhrase(text: "Necesito agua ahora"), SavedPhrase(text: "Necesito {drink}")]
        XCTAssertEqual(WordPrediction.suggestions(for: "Necesito ", items: [], phrases: phrases), ["agua"])
        XCTAssertEqual(WordPrediction.completing("Necesito ", with: "agua"), "Necesito agua ")
    }

    @MainActor
    func testBoardLanguageLocalizesVocabularyCompletions() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        store.settings.communicationLanguage = "es"
        let results = WordPrediction.suggestions(for: "neces", items: store.localizedItems(), phrases: [])
        XCTAssertTrue(results.contains("necesito"))
    }

    func testNoNextWordSuggestionAfterSentenceEnd() {
        XCTAssertTrue(WordPrediction.suggestions(for: "I need. ", items: StarterVocabulary.items,
                                                   phrases: StarterVocabulary.phrases).isEmpty)
        XCTAssertTrue(WordPrediction.suggestions(for: " ", items: StarterVocabulary.items,
                                                   phrases: StarterVocabulary.phrases).isEmpty)
    }

    func testBoardHintsMatchOnlyExistingSingleWordButtons() {
        let want = CommunicationItem(label: "want", symbol: "🤲", message: "want", category: "Core")
        let water = CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Needs")
        let wholePhrase = CommunicationItem(label: "I want", symbol: "💬", message: "I want", category: "Core")
        let items = [wholePhrase, want, water]
        let phrases = [SavedPhrase(text: "I want water")]
        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I", items: items, phrases: phrases), [want.id])
        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I want", items: items, phrases: phrases), [water.id])
        XCTAssertTrue(WordPrediction.boardItemIDs(after: "I want.", items: items, phrases: phrases).isEmpty)
        XCTAssertTrue(WordPrediction.boardItemIDs(after: "", items: items, phrases: phrases).isEmpty)
    }

    func testBoardHintsUseHistoryOnlyWhenItIsProvided() {
        let quiet = CommunicationItem(label: "quiet", symbol: "🤫", message: "quiet", category: "Sensory")
        let history = [SpokenMessage(text: "I need quiet")]
        XCTAssertTrue(WordPrediction.boardItemIDs(after: "I need", items: [quiet], phrases: []).isEmpty)
        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I need", items: [quiet], phrases: [],
                                                   history: history), [quiet.id])
    }
}
