import XCTest
@testable import OpenVoice

final class SentencePredictionTests: XCTestCase {
    @MainActor
    func testStoreReusesSentenceSuggestionsAndRefreshesAfterDraftAndPhraseChanges() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("sentence-cache.json"))
        store.typedMessage = "I need"

        let count = store.sentenceSuggestionComputationCount
        let initial = store.sentenceSuggestions()
        XCTAssertEqual(store.sentenceSuggestions(), initial)
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count + 1)

        XCTAssertTrue(store.addPhrase("I need nebula shelter now"))
        XCTAssertTrue(store.sentenceSuggestions().contains("I need nebula shelter now"))
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count + 2)

        store.typedMessage = "I want"
        _ = store.sentenceSuggestions()
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count + 3)

        store.settings.communicationLanguage = "es"
        _ = store.sentenceSuggestions()
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count + 4)
    }

    @MainActor
    func testUnrelatedSavesKeepPredictionCacheWhileQuickRepliesRefreshIt() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("prediction-cache.json"))
        store.typedMessage = "Please help"
        let initial = store.sentenceSuggestions()
        let count = store.sentenceSuggestionComputationCount

        store.settings.highContrast.toggle()
        store.addRoutineStep("Wash hands", symbol: "🧼")
        XCTAssertEqual(store.sentenceSuggestions(), initial)
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count)

        store.settings.quickResponses.append(QuickResponse(text: "Please help with the door"))
        XCTAssertTrue(store.sentenceSuggestions().contains("Please help with the door"))
        XCTAssertEqual(store.sentenceSuggestionComputationCount, count + 1)
    }

    func testLargePhraseAndHistorySuggestionsPerformance() {
        let phrases = (1...1_000).map { SavedPhrase(text: "Please help with item \($0) now") }
            + [SavedPhrase(text: "I need help now")]
        let history = (1...50).map { SpokenMessage(text: "I need a break number \($0)") }
            + (1...5_000).map { SpokenMessage(text: "Partner turn \($0)", speaker: .partner) }
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 1...30 {
                XCTAssertFalse(SentencePrediction.suggestions(
                    for: "I need", phrases: phrases, history: history).isEmpty)
            }
        }
    }

    func testSavedPhraseCompletesOnlyCurrentSentence() throws {
        let phrase = SavedPhrase(text: "I need a break, please.")
        let draft = "Hello. I need"
        XCTAssertEqual(SentencePrediction.suggestions(for: draft, phrases: [phrase]),
                       [phrase.text])
        XCTAssertEqual(SentencePrediction.completing(draft, with: phrase.text),
                       "Hello. I need a break, please.")
    }

    func testQuickReplyUsesChosenLanguageAndHistoryIsSuppliedExplicitly() {
        let reply = QuickResponse(text: "I need a break", spanishText: "Necesito un descanso")
        XCTAssertEqual(SentencePrediction.suggestions(for: "Necesito", phrases: [],
                                                     quickResponses: [reply], language: "es"),
                       ["Necesito un descanso"])
        let recent = [SpokenMessage(text: "Please wait for me")]
        XCTAssertTrue(SentencePrediction.suggestions(for: "Please", phrases: []).isEmpty)
        XCTAssertEqual(SentencePrediction.suggestions(for: "Please", phrases: [], history: recent),
                       ["Please wait for me"])
    }

    func testDuplicateMessagesAndUnfilledTemplatesAreNotShown() {
        let phrases = [SavedPhrase(text: "Can you help me?"),
                       SavedPhrase(text: "Can you help me?"),
                       SavedPhrase(text: "Can you help {name}?")]
        let suggestions = SentencePrediction.suggestions(for: "Can you", phrases: phrases,
            history: [SpokenMessage(text: "Can you help me?")])
        XCTAssertEqual(suggestions, ["Can you help me?"])
    }

    func testNoCompletionForShortFinishedOrChangedDraft() {
        let phrase = SavedPhrase(text: "I need help now")
        XCTAssertTrue(SentencePrediction.suggestions(for: "I", phrases: [phrase]).isEmpty)
        XCTAssertTrue(SentencePrediction.suggestions(for: "I ", phrases: [phrase]).isEmpty)
        XCTAssertTrue(SentencePrediction.suggestions(for: "I need.", phrases: [phrase]).isEmpty)
        XCTAssertNil(SentencePrediction.completing("I want", with: phrase.text))
    }
}
