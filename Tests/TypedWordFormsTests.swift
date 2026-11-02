import XCTest
@testable import OpenVoice

final class TypedWordFormsTests: XCTestCase {
    func testSpanishAccentedWordAndVerbAtCursor() throws {
        let noun = try XCTUnwrap(TypedWordForms.context(in: "Veo lápiz", cursorOffset: 6,
                                                         language: "es"))
        XCTAssertEqual(noun.word, "lápiz")
        let plural = try XCTUnwrap(noun.options.first { $0.kind == .pluralOrPresent })
        let pluralResult = try XCTUnwrap(TypedWordForms.replacing("Veo lápiz", context: noun,
                                                                  with: plural))
        XCTAssertEqual(pluralResult.text, "Veo lápices")
        XCTAssertEqual(pluralResult.cursorOffset, 11)

        let verb = try XCTUnwrap(TypedWordForms.context(in: "comer ahora", cursorOffset: 3,
                                                         language: "es"))
        let future = try XCTUnwrap(verb.options.first { $0.kind == .future })
        XCTAssertEqual(TypedWordForms.replacing("comer ahora", context: verb,
                                               with: future)?.text, "comeré ahora")
        XCTAssertNil(TypedWordForms.context(in: "quiero", cursorOffset: 6, language: "es"))
    }

    func testChangesWordAtCursorWithoutChangingFollowingWords() throws {
        let text = "I go home"
        let context = try XCTUnwrap(TypedWordForms.context(in: text, cursorOffset: 4))
        XCTAssertEqual(context.word, "go")
        let past = try XCTUnwrap(context.options.first { $0.kind == .past })
        let result = try XCTUnwrap(TypedWordForms.replacing(text, context: context, with: past))
        XCTAssertEqual(result.text, "I went home")
        XCTAssertEqual(result.cursorOffset, 6)
    }

    func testCursorAtWordStartAndTrailingSpacesSelectWholeWord() throws {
        let atStart = try XCTUnwrap(TypedWordForms.context(in: "I go home", cursorOffset: 2))
        XCTAssertEqual(atStart.word, "go")
        let text = "I go  "
        let context = try XCTUnwrap(TypedWordForms.context(in: text, cursorOffset: text.count))
        let future = try XCTUnwrap(context.options.first { $0.kind == .future })
        let result = try XCTUnwrap(TypedWordForms.replacing(text, context: context, with: future))
        XCTAssertEqual(result.text, "I will go  ")
        XCTAssertEqual(result.cursorOffset, 9)
    }

    func testPunctuationAndNonEnglishWordsDoNotOfferPartialForms() {
        XCTAssertNil(TypedWordForms.context(in: "I go.", cursorOffset: 5))
        XCTAssertNil(TypedWordForms.context(in: "mañana", cursorOffset: 6))
        XCTAssertNil(TypedWordForms.context(in: "we'll", cursorOffset: 5))
        XCTAssertNil(TypedWordForms.context(in: "I go home", cursorOffset: 0))
    }

    func testStaleContextDoesNotReplaceAnotherWord() throws {
        let context = try XCTUnwrap(TypedWordForms.context(in: "I go home", cursorOffset: 4))
        let past = try XCTUnwrap(context.options.first { $0.kind == .past })
        XCTAssertNil(TypedWordForms.replacing("I do home", context: context, with: past))
    }
}
