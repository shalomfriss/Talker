import Foundation

struct VisualSceneBoard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var imageData: Data
    var hotspots: [SceneHotspot]
    var videoData: Data? = nil

    var isVideoScene: Bool { videoData != nil }

    var hasValidMedia: Bool {
        if videoData == nil && hotspots.allSatisfy({ $0.videoData == nil }) { return true }
        let totalBytes = imageData.count + (videoData?.count ?? 0) +
            hotspots.reduce(0) { $0 + ($1.videoData?.count ?? 0) + ($1.videoPosterData?.count ?? 0) }
        return (videoData.map { !$0.isEmpty && $0.count <= SceneVideoProcessing.maxStoredBytes } ?? true) &&
            totalBytes <= SceneVideoProcessing.maxSceneBytes
    }
}
