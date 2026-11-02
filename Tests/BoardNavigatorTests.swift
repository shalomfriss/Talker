import XCTest
@testable import OpenVoice

final class BoardNavigatorTests: XCTestCase {
    func testNavigateStaysOnBoardUntilBack() {
        var navigator = BoardNavigator()
        XCTAssertTrue(navigator.open("Needs", behavior: .navigate, availableBoards: ["Core", "Needs"]))
        XCTAssertEqual(navigator.currentBoard, "Needs")
        navigator.selectWord()
        XCTAssertEqual(navigator.currentBoard, "Needs")
        navigator.back()
        XCTAssertEqual(navigator.currentBoard, "Core")
        XCTAssertTrue(navigator.history.isEmpty)
    }

    func testVisitReturnsAfterOneSelectionThroughNestedPages() {
        var navigator = BoardNavigator()
        XCTAssertTrue(navigator.open("Needs", behavior: .visit,
                                     availableBoards: ["Core", "Needs", "Food"]))
        XCTAssertTrue(navigator.open("Food", behavior: .navigate,
                                     availableBoards: ["Core", "Needs", "Food"]))
        navigator.selectWord()
        XCTAssertEqual(navigator.currentBoard, "Core")
        XCTAssertTrue(navigator.history.isEmpty)
    }

    func testNestedVisitsAndDirectBoardChoice() {
        var navigator = BoardNavigator()
        let boards = ["Core", "Needs", "Food"]
        XCTAssertTrue(navigator.open("Needs", behavior: .visit, availableBoards: boards))
        XCTAssertTrue(navigator.open("Food", behavior: .visit, availableBoards: boards))
        navigator.selectWord()
        XCTAssertEqual(navigator.currentBoard, "Core")

        XCTAssertTrue(navigator.open("Needs", behavior: .visit, availableBoards: boards))
        navigator.goTo("Food")
        navigator.selectWord()
        XCTAssertEqual(navigator.currentBoard, "Food")
        XCTAssertTrue(navigator.history.isEmpty)
    }

    func testBackAndHomeButtonsUseNavigationHistory() {
        var navigator = BoardNavigator()
        let boards = ["Core", "Needs", "Food"]
        XCTAssertTrue(navigator.open("Needs", behavior: .navigate, availableBoards: boards))
        XCTAssertTrue(navigator.open("Food", behavior: .navigate, availableBoards: boards))
        navigator.back()
        XCTAssertEqual(navigator.currentBoard, "Needs")
        navigator.goTo("Core")
        XCTAssertEqual(navigator.currentBoard, "Core")
        XCTAssertTrue(navigator.history.isEmpty)
        navigator.back()
        XCTAssertEqual(navigator.currentBoard, "Core")
    }

    func testRemovedBoardReturnsToSelectedHomeBoard() {
        var navigator = BoardNavigator()
        navigator.goTo("Garden")
        navigator.reconcile(availableBoards: ["Core", "Needs"], homeBoard: "Needs")
        XCTAssertEqual(navigator.currentBoard, "Needs")
        XCTAssertTrue(navigator.history.isEmpty)
    }
}
