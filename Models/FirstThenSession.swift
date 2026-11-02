import Foundation

struct FirstThenSession {
    let steps: [RoutineStep]
    private(set) var completedStepIDs: Set<UUID> = []

    init(template: RoutineTemplate) {
        steps = template.freshSteps()
    }

    var completedCount: Int { completedStepIDs.count }

    var remainingSteps: [RoutineStep] {
        steps.filter { !completedStepIDs.contains($0.id) }
    }

    var completedSteps: [RoutineStep] {
        steps.filter { completedStepIDs.contains($0.id) }
    }

    var snapshotSteps: [RoutineStep] {
        steps.map { step in
            var copy = step
            copy.isComplete = completedStepIDs.contains(step.id)
            return copy
        }
    }

    var current: RoutineStep? {
        remainingSteps.first
    }

    var next: RoutineStep? {
        remainingSteps.dropFirst().first
    }

    func isComplete(_ step: RoutineStep) -> Bool {
        completedStepIDs.contains(step.id)
    }

    @discardableResult
    mutating func setComplete(_ stepID: UUID, to isComplete: Bool) -> Bool {
        guard steps.contains(where: { $0.id == stepID }) else { return false }
        if isComplete { return completedStepIDs.insert(stepID).inserted }
        return completedStepIDs.remove(stepID) != nil
    }

    @discardableResult
    mutating func advance() -> Bool {
        guard let current else { return false }
        return setComplete(current.id, to: true)
    }

    mutating func reset() {
        completedStepIDs.removeAll()
    }
}
