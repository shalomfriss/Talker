import XCTest
@testable import OpenVoice

final class BoardWordFinderTests: XCTestCase {
    func testSameWordOnDifferentBoardsKeepsDistinctPaths() {
        let results = BoardWordFinder.matches("water", in: StarterVocabulary.items, labelFor: { $0.label })
        XCTAssertEqual(results.filter { $0.displayLabel == "water" }.count, 2)
        XCTAssertTrue(results.contains { $0.path == ["Core", "Food", "water"] })
        XCTAssertTrue(results.contains { $0.path == ["Core", "Needs", "water"] })
    }

    func testStageHiddenStarterCanBeFoundButManualHidingAndInactiveDimmingCannot() throws {
        var later = try XCTUnwrap(StarterVocabulary.items.first {
            $0.category == "Core" && $0.label == "like"
        })
        XCTAssertEqual(ProgressiveVocabulary.displayed(later, stage: .start).boardVisibility, .hidden)
        XCTAssertEqual(BoardWordFinder.matches("like", in: [later], labelFor: { $0.label }).count, 1)
        later.visibility = .hidden
        XCTAssertTrue(BoardWordFinder.matches("like", in: [later], labelFor: { $0.label }).isEmpty)
        later.visibility = .dimmed
        XCTAssertTrue(BoardWordFinder.matches("like", in: [later], dimmedButtonsActive: false,
                                              labelFor: { $0.label }).isEmpty)
    }

    func testLocalizedLabelSearchAndExactResultRanking() {
        let items = [
            CommunicationItem(label: "water bottle", symbol: "🍼", message: "water bottle", category: "Needs"),
            CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Food")
        ]
        let results = BoardWordFinder.matches("agua", in: items) {
            $0.label == "water" ? "agua" : "botella de agua"
        }
        XCTAssertEqual(results.map(\.displayLabel), ["agua", "botella de agua"])
        XCTAssertEqual(results.first?.path, ["Core", "Food", "agua"])
        XCTAssertTrue(BoardWordFinder.matches(" ", in: items, labelFor: { $0.label }).isEmpty)
    }
}
