import Foundation

struct SoundBoardClip: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var audioData: Data

    static let maximumCount = 12
    static let maximumNameLength = 40
    static let maximumAudioBytes = 2_000_000

    static func cleaned(_ clips: [SoundBoardClip]) -> [SoundBoardClip] {
        var seen = Set<UUID>()
        return Array(clips.compactMap { clip -> SoundBoardClip? in
            var result = clip
            result.name = clip.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.name.isEmpty,
                  result.name.count <= maximumNameLength,
                  !result.audioData.isEmpty,
                  result.audioData.count <= maximumAudioBytes,
                  seen.insert(result.id).inserted else { return nil }
            return result
        }.prefix(maximumCount))
    }
}

enum BuiltInSound: String, CaseIterable, Identifiable {
    case hello, attention, happy, celebrate, calm, pause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hello: "Hello"
        case .attention: "Attention"
        case .happy: "Happy"
        case .celebrate: "Celebrate"
        case .calm: "Calm"
        case .pause: "Pause"
        }
    }

    var symbol: String {
        switch self {
        case .hello: "hand.wave.fill"
        case .attention: "bell.fill"
        case .happy: "face.smiling.fill"
        case .celebrate: "party.popper.fill"
        case .calm: "leaf.fill"
        case .pause: "pause.circle.fill"
        }
    }

    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "wav", subdirectory: "SoundBoard")
    }
}
