import Foundation

enum SceneHotspotBehavior: String, Codable, CaseIterable {
    case speakAndAdd
    case speakOnly
    case addOnly

    var title: String {
        switch self {
        case .speakAndAdd: "Speak and add"
        case .speakOnly: "Speak only"
        case .addOnly: "Add only"
        }
    }
}

struct SceneHotspot: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var option: ChoiceOption
    var x: Double
    var y: Double
    var destinationSceneID: UUID? = nil
    var width: Double? = nil
    var height: Double? = nil
    var backgroundColorHex: String? = nil
    var showsLabel: Bool? = nil
    var behavior: SceneHotspotBehavior? = nil
    var spokenText: String? = nil
    var videoData: Data? = nil
    var videoPosterData: Data? = nil

    init(id: UUID = UUID(), option: ChoiceOption, x: Double, y: Double,
         destinationSceneID: UUID? = nil, width: Double? = nil, height: Double? = nil,
         backgroundColorHex: String? = nil, showsLabel: Bool? = nil,
         behavior: SceneHotspotBehavior? = nil, spokenText: String? = nil,
         videoData: Data? = nil, videoPosterData: Data? = nil) {
        self.id = id
        self.option = option
        self.x = x
        self.y = y
        self.destinationSceneID = destinationSceneID
        self.width = width
        self.height = height
        self.backgroundColorHex = backgroundColorHex
        self.showsLabel = showsLabel
        self.behavior = behavior
        self.spokenText = spokenText
        self.videoData = videoData
        self.videoPosterData = videoPosterData
    }

    var effectiveBehavior: SceneHotspotBehavior { behavior ?? .speakAndAdd }

    var hasValidMedia: Bool {
        guard let videoData else { return videoPosterData == nil }
        return !videoData.isEmpty && videoData.count <= SceneVideoProcessing.maxHotspotBytes &&
            videoPosterData.map { !$0.isEmpty && $0.count <= 2 * 1_048_576 } == true &&
            destinationSceneID == nil
    }

    var hasValidPosition: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) &&
        (width.map { $0.isFinite && (0.12...0.8).contains($0) } ?? true) &&
        (height.map { $0.isFinite && (0.08...0.5).contains($0) } ?? true) &&
        (backgroundColorHex.map { ButtonColorValue(text: $0) != nil } ?? true) &&
        (spokenText.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true)
    }

    func moved(toX newX: Double, y newY: Double) -> SceneHotspot {
        var updated = self
        let horizontalInset = width.map { $0 / 2 } ?? 0
        let verticalInset = height.map { $0 / 2 } ?? 0
        updated.x = newX.isFinite ? min(1 - horizontalInset, max(horizontalInset, newX)) : 0.5
        updated.y = newY.isFinite ? min(1 - verticalInset, max(verticalInset, newY)) : 0.5
        return updated
    }
}
