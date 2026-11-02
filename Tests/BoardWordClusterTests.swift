import XCTest
@testable import OpenVoice

final class BoardWordClusterTests: XCTestCase {
    func testGroupsPreserveEveryBoardSlotAndItsOrder() {
        let items = Array(StarterVocabulary.items.prefix(25))
        let groups = BoardWordCluster.groups(for: items)
        XCTAssertEqual(groups.count, 6)
        XCTAssertEqual(groups.flatMap(\.items), items)
        XCTAssertEqual(groups.map(\.startIndex), [0, 5, 9, 13, 17, 21])
        XCTAssertEqual(groups.map(\.rangeLabel), [
            "Buttons 1–5", "Buttons 6–9", "Buttons 10–13",
            "Buttons 14–17", "Buttons 18–21", "Buttons 22–25"
        ])

        var changed = items
        changed[2].visibility = .hidden
        changed[8].visibility = .dimmed
        let afterVisibilityChange = BoardWordCluster.groups(for: changed)
        XCTAssertEqual(afterVisibilityChange.map(\.startIndex), groups.map(\.startIndex))
        XCTAssertEqual(afterVisibilityChange.map(\.rangeLabel), groups.map(\.rangeLabel))
        XCTAssertEqual(afterVisibilityChange.flatMap(\.items).map(\.id), items.map(\.id))
    }

    func testSmallAndEmptyBoardsRemainReachable() {
        let items = Array(StarterVocabulary.items.prefix(3))
        XCTAssertEqual(BoardWordCluster.groups(for: items).map { $0.items.count }, [1, 1, 1])
        XCTAssertTrue(BoardWordCluster.groups(for: []).isEmpty)
    }

    func testOlderSettingsWithoutPictureGroupingKeepFullGrid() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "groupedPictureBoard")
        let oldData = try JSONSerialization.data(withJSONObject: json)
        XCTAssertFalse(try JSONDecoder().decode(AppSettings.self, from: oldData).groupedPictureBoard)
    }
}
