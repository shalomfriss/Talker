import Foundation

struct RepeatTapFilter {
    private var lastItemID: UUID?
    private var lastTime = Date.distantPast

    mutating func allows(_ itemID: UUID, at time: Date = Date(), interval: Double) -> Bool {
        if interval > 0, lastItemID == itemID, time.timeIntervalSince(lastTime) < interval {
            return false
        }
        lastItemID = itemID
        lastTime = time
        return true
    }

    mutating func reset() {
        lastItemID = nil
        lastTime = .distantPast
    }
}
