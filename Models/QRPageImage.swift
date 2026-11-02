import CoreImage.CIFilterBuiltins
import UIKit
import Vision

enum QRPageImage {
    static func make(_ code: String) throws -> UIImage {
        guard code.utf8.count <= QRPageTransfer.maxCodeBytes else {
            throw QRPageTransferError.tooLarge
        }
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(code.utf8)
        generator.correctionLevel = "L"
        guard let output = generator.outputImage else { throw QRPageTransferError.tooLarge }
        let border = output.extent.insetBy(dx: -4, dy: -4)
        let white = CIImage(color: .white).cropped(to: border)
        let padded = output.composited(over: white)
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
            throw QRPageTransferError.tooLarge
        }
        return UIImage(cgImage: cgImage)
    }

    static func read(from imageData: Data) throws -> String {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        if (try? VNImageRequestHandler(data: imageData).perform([request])) != nil,
           let code = request.results?.first?.payloadStringValue {
            return code
        }
        guard let image = CIImage(data: imageData),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
              let code = detector.features(in: image).compactMap({ ($0 as? CIQRCodeFeature)?.messageString }).first else {
            throw QRPageTransferError.invalidCode
        }
        return code
    }
}
