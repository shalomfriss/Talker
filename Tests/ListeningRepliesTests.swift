import XCTest
@testable import OpenVoice

final class ListeningRepliesTests: XCTestCase {
    func testRelevantPersonalPhraseComesFirstAndTemplateIsNotOffered() {
        let phrase = SavedPhrase(text: "I need water.", audioData: Data([1, 2, 3]))
        let unrelated = SavedPhrase(text: "I want to play outside.")
        let template = SavedPhrase(text: "I need {drink}.")
        let replies = ListeningReplies.suggestions(
            for: "Would you like water?", language: "en",
            phrases: [unrelated, template, phrase], quickReplies: QuickResponse.starterReplies)

        XCTAssertEqual(replies.first?.text, "I need water.")
        XCTAssertEqual(replies.first?.audioData, Data([1, 2, 3]))
        XCTAssertEqual(replies.first?.source, .personalPhrase)
        XCTAssertFalse(replies.contains { $0.text.contains("{drink}") })
        XCTAssertTrue(replies.contains { $0.text == "Maybe" })
        XCTAssertTrue(replies.contains { $0.text == "Please say that again." })
    }

    func testQuestionWithoutQuestionMarkAndSpanishReplies() {
        let english = ListeningReplies.suggestions(for: "Can we go", language: "en",
                                                    phrases: [], quickReplies: [])
        XCTAssertTrue(english.contains { $0.text == "Yes" })
        XCTAssertTrue(english.contains { $0.text == "No" })

        let spanish = ListeningReplies.suggestions(for: "¿Quieres agua?", language: "es",
                                                    phrases: [], quickReplies: QuickResponse.starterReplies)
        XCTAssertTrue(spanish.contains { ListeningReplies.key(for: $0.text) == "si" })
        XCTAssertTrue(spanish.contains { $0.text == "¿Puedes repetirlo?" })
        XCTAssertEqual(spanish.filter { ListeningReplies.key(for: $0.text) == "si" }.count, 1)
    }

    func testPersonalQuickReplyAndPunctuationDuplicates() {
        let quick = QuickResponse(text: "Wait, please.")
        let replies = ListeningReplies.suggestions(for: "Please wait", language: "en",
                                                   phrases: [SavedPhrase(text: "Wait please")],
                                                   quickReplies: [quick])
        XCTAssertEqual(replies.filter { $0.id == "wait please" }.count, 1)
        XCTAssertEqual(replies.first?.source, .personalPhrase)
        XCTAssertTrue(replies.contains { $0.text == "I hear you." })
    }
}
