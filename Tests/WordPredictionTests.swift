import XCTest
@testable import OpenVoice

final class WordPredictionTests: XCTestCase {
    func testThousandWordTypingSuggestionsPerformance() {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        let items = (1...1_000).map { index in
            let letters = String([alphabet[index / 676], alphabet[(index / 26) % 26], alphabet[index % 26]])
            return CommunicationItem(label: "word\(letters)", symbol: "💬",
                                     message: "I want word\(letters) now", category: "Core")
        }
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            for index in 1...30 {
                let suggestions = WordPrediction.suggestions(
                    for: "worda\(alphabet[index % 26])", items: items, phrases: [], limit: 5)
                XCTAssertFalse(suggestions.isEmpty)
            }
        }
    }

    @MainActor
    func testTypedSuggestionsReuseComputationAndRefreshAfterVocabularyChanges() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("typed-cache.json"))
        store.typedMessage = "luminar"

        let initialCount = store.wordSuggestionComputationCount
        let initialPreparations = store.wordSuggestionItemPreparationCount
        let initial = store.wordSuggestions()
        XCTAssertEqual(store.wordSuggestions(), initial)
        XCTAssertEqual(store.wordSuggestionComputationCount, initialCount + 1)
        XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 1)

        let short = store.wordSuggestions(limit: 3)
        XCTAssertEqual(store.wordSuggestions(limit: 3), short)
        XCTAssertEqual(store.wordSuggestionComputationCount, initialCount + 2)
        XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 1)

        store.addItem(label: "luminaraword", symbol: "💬", message: "luminaraword",
                      category: "Core", imageData: nil)
        XCTAssertTrue(store.wordSuggestions().contains("luminaraword"))
        XCTAssertEqual(store.wordSuggestionComputationCount, initialCount + 3)
        XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 2)

        store.typedMessage = "differentprefix"
        XCTAssertFalse(store.wordSuggestions().contains("luminaraword"))
        XCTAssertEqual(store.wordSuggestionComputationCount, initialCount + 4)
        XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 2)

        store.settings.communicationLanguage = "es"
        store.typedMessage = "respl"
        XCTAssertFalse(store.wordSuggestions().contains("resplandorcito"))
        XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 3)

        let item = store.items.first { $0.label == "luminaraword" }
        XCTAssertNotNil(item)
        if let item {
            store.updateSpanishTranslation(for: item.id, label: "resplandorcito",
                                           message: "resplandorcito")
            XCTAssertTrue(store.wordSuggestions().contains("resplandorcito"))
            XCTAssertEqual(store.wordSuggestionItemPreparationCount, initialPreparations + 4)
        }
    }

    @MainActor
    func testBoardSuggestionCacheReusesResultAndInvalidatesForContentChanges() {
        let cache = BoardSuggestionCache()
        let profile = UUID()
        let firstWord = UUID()
        let secondWord = UUID()
        var calculations = 0
        let base = BoardSuggestionKey(profileID: profile, message: "I want",
                                      contentRevision: 1, exploringAllWords: false,
                                      finderTargetID: nil)
        func suggestions(for key: BoardSuggestionKey) -> Set<UUID> {
            cache.value(for: key) {
                calculations += 1
                return calculations == 1 ? [firstWord] : [secondWord]
            }
        }
        XCTAssertEqual(suggestions(for: base), [firstWord])
        XCTAssertEqual(suggestions(for: base), [firstWord])
        XCTAssertEqual(calculations, 1)
        XCTAssertEqual(suggestions(for: BoardSuggestionKey(profileID: profile, message: "I need",
            contentRevision: 1, exploringAllWords: false, finderTargetID: nil)), [secondWord])
        XCTAssertEqual(suggestions(for: BoardSuggestionKey(profileID: profile, message: "I need",
            contentRevision: 2, exploringAllWords: false, finderTargetID: nil)), [secondWord])
        XCTAssertEqual(suggestions(for: BoardSuggestionKey(profileID: UUID(), message: "I need",
            contentRevision: 2, exploringAllWords: false, finderTargetID: nil)), [secondWord])
        XCTAssertEqual(calculations, 4)
    }

    @MainActor
    func testVocabularyEditsAdvancePredictionContentRevision() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("prediction-cache.json"))
        let initial = store.predictionContentRevision
        store.addItem(label: "coconut", symbol: "🥥", message: "coconut", category: "Food",
                      imageData: nil)
        XCTAssertGreaterThan(store.predictionContentRevision, initial)
    }

    func testBoardHintsFindAvailableWordAfterLargeUnavailableVocabulary() {
        let water = CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Needs")
        let unavailable = (0..<800).map { number in
            let a = Character(UnicodeScalar(97 + number / 676)!)
            let b = Character(UnicodeScalar(97 + (number / 26) % 26)!)
            let c = Character(UnicodeScalar(97 + number % 26)!)
            return SavedPhrase(text: "I want \(a)\(b)\(c)")
        }
        let phrases = unavailable + [SavedPhrase(text: "I want water")]

        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I want", items: [water],
                                                   phrases: phrases, limit: 1), [water.id])
    }

    func testBoardHintsKeepLearnedWordsAheadOfOrdinaryWords() {
        let juice = CommunicationItem(label: "juice", symbol: "🧃", message: "juice", category: "Food")
        let water = CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Needs")
        var learned = LearnedPredictionModel()
        learned.learn("I want juice", language: "en")
        learned.learn("I want juice", language: "en")
        let phrases = [SavedPhrase(text: "I want water")]

        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I want", items: [juice, water],
                                                   phrases: phrases, learned: learned, limit: 1), [juice.id])
        XCTAssertEqual(WordPrediction.boardItemIDs(after: "I want", items: [water],
                                                   phrases: phrases, learned: learned, limit: 1), [water.id])
    }

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
