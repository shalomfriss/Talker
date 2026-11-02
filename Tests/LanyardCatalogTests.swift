import XCTest
@testable import OpenVoice

final class LanyardCatalogTests: XCTestCase {
    func testOnlySpeakingCardsOnChosenBoardAreShownInOrder() {
        let core = CommunicationItem(label: "yes", symbol: "✓", message: "yes", category: "Core")
        var favorite = CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Needs")
        favorite.isFavorite = true
        var link = CommunicationItem(label: "Food", symbol: "🍽", message: "Food", category: "Core")
        link.destinationBoard = "Food"
        var hidden = CommunicationItem(label: "hidden", symbol: "?", message: "hidden", category: "Core")
        hidden.visibility = .hidden
        let items = [core, favorite, link, hidden]

        XCTAssertEqual(LanyardCatalog.items(in: "Core", from: items, dimmedButtonsActive: true).map(\.label), ["yes"])
        XCTAssertEqual(LanyardCatalog.items(in: "Favorites", from: items, dimmedButtonsActive: true).map(\.label), ["water"])
    }

    func testInactiveDimmedAndControlButtonsAreExcluded() {
        var dimmed = CommunicationItem(label: "stop", symbol: "✋", message: "stop", category: "Core")
        dimmed.visibility = .dimmed
        var clear = CommunicationItem(label: "clear", symbol: "×", message: "clear", category: "Core")
        clear.action = .clearMessage
        let items = [dimmed, clear]

        XCTAssertTrue(LanyardCatalog.items(in: "Core", from: items, dimmedButtonsActive: false).isEmpty)
        XCTAssertEqual(LanyardCatalog.items(in: "Core", from: items, dimmedButtonsActive: true).map(\.label), ["stop"])
    }
}
