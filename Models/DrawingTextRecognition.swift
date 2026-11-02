import Foundation
import Vision

enum DrawingTextRecognitionError: LocalizedError {
    case noWriting

    var errorDescription: String? {
        switch self {
        case .noWriting: "No readable writing was found. Try writing larger, or use Type in Speak."
        }
    }
}

enum DrawingTextRecognition {
    static func recognize(imageData: Data) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(data: imageData, options: [:])
        try handler.perform([request])

        var lines: [(height: CGFloat, observations: [VNRecognizedTextObservation])] = []
        for observation in (request.results ?? []).sorted(by: {
            $0.boundingBox.midY > $1.boundingBox.midY
        }) {
            if let index = lines.firstIndex(where: {
                abs($0.height - observation.boundingBox.midY) < 0.03
            }) {
                lines[index].observations.append(observation)
            } else {
                lines.append((observation.boundingBox.midY, [observation]))
            }
        }
        let text = lines.flatMap { line in
            line.observations.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first?.string }
        }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DrawingTextRecognitionError.noWriting }
        return text
    }
}
