import XCTest
@testable import OpenVoice

final class RepeatTapFilterTests: XCTestCase {
    func testSameWordIsFilteredButDifferentWordsRespondImmediately() {
        var filter = RepeatTapFilter()
        let first = UUID()
        let second = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(filter.allows(first, at: start, interval: 0.8))
        XCTAssertFalse(filter.allows(first, at: start.addingTimeInterval(0.3), interval: 0.8))
        XCTAssertTrue(filter.allows(second, at: start.addingTimeInterval(0.4), interval: 0.8))
        XCTAssertTrue(filter.allows(first, at: start.addingTimeInterval(0.5), interval: 0.8))
        XCTAssertFalse(filter.allows(first, at: start.addingTimeInterval(0.6), interval: 0.8))
        XCTAssertTrue(filter.allows(first, at: start.addingTimeInterval(1.4), interval: 0.8))
    }

    func testOffAndReset() {
        var filter = RepeatTapFilter()
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(filter.allows(id, at: start, interval: 0))
        XCTAssertTrue(filter.allows(id, at: start, interval: 0))
        XCTAssertFalse(filter.allows(id, at: start.addingTimeInterval(0.1), interval: 0.4))
        filter.reset()
        XCTAssertTrue(filter.allows(id, at: start.addingTimeInterval(0.2), interval: 0.4))
    }
}
