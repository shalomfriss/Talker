import XCTest
@testable import OpenVoice

final class PracticeSessionTests: XCTestCase {
    func testEveryActivityOffersDifferentPartnerAndCommunicatorIdeas() {
        for activity in PracticeActivity.allCases {
            let english = activity.ideas(language: "en")
            let spanish = activity.ideas(language: "es")
            XCTAssertEqual(english.count, 3)
            XCTAssertEqual(spanish.count, english.count)
            XCTAssertFalse(activity.title(language: "en").isEmpty)
            XCTAssertFalse(activity.title(language: "es").isEmpty)
            XCTAssertTrue(english.allSatisfy { !$0.partner.isEmpty && !$0.communicator.isEmpty })
            XCTAssertTrue(spanish.allSatisfy { !$0.partner.isEmpty && !$0.communicator.isEmpty })
        }
    }

    func testTurnAndIdeaCanChangeIndependentlyAndCycle() {
        var session = PracticeSession(activity: .talkAboutInterests)
        XCTAssertEqual(session.turn, .partner)
        XCTAssertEqual(session.prompt(language: "en"), "Show something you like.")
        session.switchTurn()
        XCTAssertEqual(session.turn, .communicator)
        XCTAssertEqual(session.prompt(language: "en"), "Say what you like or do not like.")
        session.nextIdea()
        XCTAssertEqual(session.turn, .communicator)
        XCTAssertEqual(session.prompt(language: "en"), "Comment on something you notice.")
        session.nextIdea()
        session.nextIdea()
        XCTAssertEqual(session.ideaIndex, 0)
        XCTAssertEqual(session.prompt(language: "es"), "Cuenta lo que te gusta o no te gusta.")
    }
}
