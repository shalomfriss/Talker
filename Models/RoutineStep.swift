import Foundation

struct RoutineStep: Identifiable, Codable, Equatable {
    static let availableDurations = [60, 180, 300, 600, 900, 1800]

    var id: UUID = UUID()
    var title: String
    var symbol: String
    var isComplete: Bool = false
    var durationSeconds: Int? = nil
    var imageData: Data? = nil
    var audioData: Data? = nil
    var spokenText: String? = nil
    var videoData: Data? = nil
    var videoPosterData: Data? = nil
    var choiceBoardID: UUID? = nil

    var displayImageData: Data? { videoData == nil ? imageData : videoPosterData }

    var hasValidVideoMedia: Bool {
        guard let videoData else { return videoPosterData == nil }
        return !videoData.isEmpty && videoData.count <= SceneVideoProcessing.maxHotspotBytes &&
            videoPosterData.map { !$0.isEmpty && $0.count <= 2 * 1_048_576 } == true
    }

    var spokenMessage: String {
        let instruction = spokenText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return instruction.isEmpty ? title : instruction
    }

    var durationLabel: String? {
        durationSeconds.map { "\($0 / 60) min" }
    }

    static func acceptsDuration(_ seconds: Int?) -> Bool {
        guard let seconds else { return true }
        return availableDurations.contains(seconds)
    }
}
