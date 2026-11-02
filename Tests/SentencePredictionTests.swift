import XCTest
@testable import OpenVoice

final class SentencePredictionTests: XCTestCase {
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
