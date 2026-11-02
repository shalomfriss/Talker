import Foundation

struct RoutineStepClock {
    let durationSeconds: Int
    private(set) var pausedSeconds: Int
    private(set) var deadline: Date?

    init(durationSeconds: Int) {
        self.durationSeconds = max(1, durationSeconds)
        pausedSeconds = self.durationSeconds
    }

    var isRunning: Bool { deadline != nil }

    func secondsRemaining(at date: Date) -> Int {
        guard let deadline else { return pausedSeconds }
        return max(0, Int(ceil(deadline.timeIntervalSince(date))))
    }

    mutating func start(at date: Date) {
        pausedSeconds = durationSeconds
        deadline = date.addingTimeInterval(TimeInterval(durationSeconds))
    }

    mutating func pause(at date: Date) {
        pausedSeconds = secondsRemaining(at: date)
        deadline = nil
    }

    mutating func resume(at date: Date) {
        if pausedSeconds == 0 { pausedSeconds = durationSeconds }
        deadline = date.addingTimeInterval(TimeInterval(pausedSeconds))
    }

    mutating func reset() {
        deadline = nil
        pausedSeconds = durationSeconds
    }

    mutating func finish() {
        deadline = nil
        pausedSeconds = 0
    }
}
