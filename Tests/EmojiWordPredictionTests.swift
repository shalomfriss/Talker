import XCTest
@testable import OpenVoice

final class EmojiWordPredictionTests: XCTestCase {
    func testEmojiOffersRelatedWordsAndCanReplaceOrKeepIt() {
        XCTAssertEqual(EmojiWordPrediction.trailingEmoji(in: "I saw 🛸"), "🛸")
        XCTAssertEqual(EmojiWordPrediction.suggestions(for: "I saw 🛸", language: "en"),
                       ["UFO", "alien", "flying saucer"])
        XCTAssertEqual(EmojiWordPrediction.replacingTrailingEmoji(in: "I saw 🛸", with: "UFO"),
                       "I saw UFO ")
        XCTAssertEqual(EmojiWordPrediction.keepingTrailingEmoji(in: "I saw 🛸"), "I saw 🛸 ")
        XCTAssertEqual(EmojiWordPrediction.replacingTrailingEmoji(in: "I saw 🛸 today", with: "UFO"),
                       "I saw 🛸 today")
    }

    func testSpanishAndSkinToneSuggestionsStayInChosenLanguage() {
        XCTAssertEqual(EmojiWordPrediction.suggestions(for: "Necesito 🚽", language: "es"),
                       ["baño", "inodoro"])
        XCTAssertEqual(EmojiWordPrediction.suggestions(for: "👋🏽", language: "es"),
                       ["hola", "adiós"])
        XCTAssertEqual(EmojiWordPrediction.suggestions(for: "❤️", language: "es"),
                       ["amor", "corazón"])
    }

    func testUnicodeNameProvidesOfflineFallbackForOtherEmoji() {
        XCTAssertEqual(EmojiWordPrediction.suggestions(for: "🪼", language: "en"),
                       ["jellyfish"])
        XCTAssertTrue(EmojiWordPrediction.suggestions(for: "🇺🇸", language: "en")
            .contains("United States"))
        XCTAssertTrue(EmojiWordPrediction.suggestions(for: "🪼", language: "es").isEmpty)
    }

    func testOrdinaryTextAndEmojiInMiddleDoNotTriggerReplacement() {
        XCTAssertNil(EmojiWordPrediction.trailingEmoji(in: "1"))
        XCTAssertNil(EmojiWordPrediction.trailingEmoji(in: "Hello 🛸 there"))
        XCTAssertTrue(EmojiWordPrediction.suggestions(for: "Hello 🛸 ").isEmpty)
        XCTAssertEqual(EmojiWordPrediction.keepingTrailingEmoji(in: "Hello"), "Hello")
    }
}
