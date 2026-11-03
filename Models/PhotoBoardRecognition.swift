import Foundation
import ImageIO
import Vision

struct PhotoBoardWord: Identifiable, Sendable {
    let id: UUID
    var text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(id: UUID = UUID(), text: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

enum PhotoBoardRecognitionError: LocalizedError {
    case unusablePhoto
    case noWords

    var errorDescription: String? {
        switch self {
        case .unusablePhoto: "This photo could not be read. Choose another photo."
        case .noWords: "No readable words were found. Try a clearer photo or add words manually."
        }
    }
}

enum PhotoBoardRecognition {
    static func recognize(imageData: Data) throws -> [PhotoBoardWord] {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PhotoBoardRecognitionError.unusablePhoto
        }
        let imageSize = CGSize(width: image.width, height: image.height)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let words = (request.results ?? []).compactMap { observation -> PhotoBoardWord? in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.3 else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 80,
                  let position = placement(for: observation.boundingBox, imageSize: imageSize) else {
                return nil
            }
            return PhotoBoardWord(text: text, x: Double(position.midX), y: Double(position.midY),
                                  width: Double(position.width), height: Double(position.height))
        }
        .sorted { lhs, rhs in
            abs(lhs.y - rhs.y) > 0.04 ? lhs.y < rhs.y : lhs.x < rhs.x
        }
        let visible = Array(words.prefix(36))
        guard !visible.isEmpty else { throw PhotoBoardRecognitionError.noWords }
        return visible
    }

    // ScenePhotoCanvas fills a 4:3 rectangle and crops the longer image dimension.
    // Vision's normalized origin is at the bottom left; scene positions start at the top left.
    static func placement(for visionBox: CGRect, imageSize: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0,
              visionBox.width > 0, visionBox.height > 0 else { return nil }
        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect: CGFloat = 4.0 / 3.0
        let visibleWidth = min(1, canvasAspect / imageAspect)
        let visibleHeight = min(1, imageAspect / canvasAspect)
        let x = (visionBox.midX - (1 - visibleWidth) / 2) / visibleWidth
        let y = (1 - visionBox.midY - (1 - visibleHeight) / 2) / visibleHeight
        guard (0...1).contains(x), (0...1).contains(y) else { return nil }
        let width = min(0.8, max(0.14, visionBox.width / visibleWidth + 0.08))
        let height = min(0.4, max(0.09, visionBox.height / visibleHeight + 0.05))
        return CGRect(x: min(1 - width / 2, max(width / 2, x)) - width / 2,
                      y: min(1 - height / 2, max(height / 2, y)) - height / 2,
                      width: width, height: height)
    }
}
