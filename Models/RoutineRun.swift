import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct RoutineRun: Identifiable, Codable, Equatable {
    enum Outcome: String, Codable {
        case completed
        case needsMoreTime

        var label: String {
            switch self {
            case .completed: "Completed"
            case .needsMoreTime: "Needed more time"
            }
        }
    }

    struct Step: Codable, Equatable {
        var title: String
        var isComplete: Bool
        var durationSeconds: Int?
    }

    var id: UUID = UUID()
    var recordedAt: Date = .now
    var outcome: Outcome
    var steps: [Step]

    var completedCount: Int { steps.filter(\.isComplete).count }

    init(outcome: Outcome, steps: [RoutineStep], recordedAt: Date = .now) {
        self.recordedAt = recordedAt
        self.outcome = outcome
        self.steps = steps.map { Step(title: $0.title, isComplete: $0.isComplete,
                                      durationSeconds: $0.durationSeconds) }
    }
}

enum RoutineHistoryCSV {
    static func data(for runs: [RoutineRun]) -> Data {
        var lines = ["recorded_at,outcome,completed_steps,total_steps,step_number,step_title,step_completed,duration_minutes"]
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime]
        for run in runs {
            for (index, step) in run.steps.enumerated() {
                let fields = [timestamp.string(from: run.recordedAt), run.outcome.label,
                              String(run.completedCount), String(run.steps.count),
                              String(index + 1), step.title, step.isComplete ? "Yes" : "No",
                              step.durationSeconds.map { String($0 / 60) } ?? ""]
                lines.append(fields.map(escape).joined(separator: ","))
            }
        }
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct RoutineCSVTransfer: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { $0.data }
    }
}
