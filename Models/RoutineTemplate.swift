import Foundation

enum FirstThenLayout: String, Codable, CaseIterable {
    case automatic
    case sideBySide
    case stacked

    var label: String {
        switch self {
        case .automatic: "Auto"
        case .sideBySide: "Side by side"
        case .stacked: "Stacked"
        }
    }
}

enum RoutineBoardMode: String, Codable, CaseIterable {
    case firstThen
    case singleStep
    case checklist
    case columns
    case envelope

    var label: String {
        switch self {
        case .firstThen: "First/Then"
        case .singleStep: "One step"
        case .checklist: "Checklist"
        case .columns: "To do / Done"
        case .envelope: "Envelope"
        }
    }
}

enum RoutineRewardFrequency: String, Codable, CaseIterable {
    case wholeRoutine
    case eachStep

    var label: String {
        switch self {
        case .wholeRoutine: "Whole routine"
        case .eachStep: "Each step"
        }
    }
}

struct RoutineTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var steps: [RoutineStep]
    var firstThenLayout: FirstThenLayout = .automatic
    var boardMode: RoutineBoardMode = .firstThen
    var rewardChartID: UUID? = nil
    var rewardFrequency: RoutineRewardFrequency = .wholeRoutine

    private enum CodingKeys: String, CodingKey { case id, name, steps, firstThenLayout, boardMode, rewardChartID, rewardFrequency }

    init(name: String, steps: [RoutineStep]) {
        self.name = name
        self.steps = steps.map { step in
            var copy = step
            copy.isComplete = false
            return copy
        }
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        steps = try values.decode([RoutineStep].self, forKey: .steps)
        firstThenLayout = try values.decodeIfPresent(FirstThenLayout.self, forKey: .firstThenLayout) ?? .automatic
        boardMode = try values.decodeIfPresent(RoutineBoardMode.self, forKey: .boardMode) ?? .firstThen
        rewardChartID = try values.decodeIfPresent(UUID.self, forKey: .rewardChartID)
        rewardFrequency = try values.decodeIfPresent(RoutineRewardFrequency.self, forKey: .rewardFrequency) ?? .wholeRoutine
    }

    func freshSteps() -> [RoutineStep] {
        steps.map { step in
            var copy = step
            copy.id = UUID()
            copy.isComplete = false
            return copy
        }
    }
}
