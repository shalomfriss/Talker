import XCTest
@testable import OpenVoice

final class SpokenChoiceTextTests: XCTestCase {
    func testRecognizedChoiceIsReviewedBeforeJoiningDraft() {
        XCTAssertEqual(SpokenChoiceText.cleaned("  Orange juice.  "), "Orange juice")
        XCTAssertEqual(SpokenChoiceText.adding(" Orange juice. ", to: "Water, Tea"), "Water\nTea\nOrange juice")
        XCTAssertTrue(QuickChoiceDraft(question: "Drinks", choices: "Water\nTea\nOrange juice").isValid)
    }

    func testDuplicateOrNinthChoiceIsNotAdded() {
        XCTAssertNil(SpokenChoiceText.adding("cafe!", to: "Café"))
        XCTAssertNil(SpokenChoiceText.adding(" ", to: "Water"))
        XCTAssertNil(SpokenChoiceText.adding("nine", to: "1,2,3,4,5,6,7,8"))
    }
}
