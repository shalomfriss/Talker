import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import UIKit

enum SceneVideoError: LocalizedError {
    case inputTooLarge
    case tooLong
    case outputTooLarge
    case sceneTooLarge
    case unusableVideo

    var errorDescription: String? {
        switch self {
        case .inputTooLarge: "Choose a video smaller than 250 MB."
        case .tooLong: "Choose a video up to one minute long."
        case .outputTooLarge: "This video is too large for a scene after compression. Try a shorter clip."
        case .sceneTooLarge: "This scene has too much media. Remove a clip before adding another."
        case .unusableVideo: "This video could not be prepared. Choose another clip."
        }
    }
}

struct SceneVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return SceneVideoFile(url: destination)
        }
    }
}

@MainActor
enum SceneVideoProcessing {
    nonisolated static let maxStoredBytes = 12 * 1_048_576
    nonisolated static let maxHotspotBytes = 8 * 1_048_576
    nonisolated static let maxSceneBytes = 24 * 1_048_576
    private static let maxInputBytes = 250 * 1_048_576
    private static let maxDuration = 60.0

    static func prepared(from url: URL, byteLimit: Int = maxStoredBytes) async throws -> (video: Data, poster: Data) {
        let inputSize = try (url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard inputSize > 0, inputSize <= maxInputBytes else { throw SceneVideoError.inputTooLarge }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw SceneVideoError.unusableVideo }
        guard duration <= maxDuration else { throw SceneVideoError.tooLong }
        guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty,
              let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality),
              exporter.supportedFileTypes.contains(.mov) else {
            throw SceneVideoError.unusableVideo
        }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: output) }
        try await exporter.export(to: output, as: .mov)
        let outputSize = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard outputSize > 0, outputSize <= byteLimit else { throw SceneVideoError.outputTooLarge }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: output))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1200, height: 1200)
        let frame = try await generator.image(at: .zero).image
        guard let poster = PhotoProcessing.preparedData(from: UIImage(cgImage: frame)) else {
            throw SceneVideoError.unusableVideo
        }
        return (try Data(contentsOf: output), poster)
    }
}
