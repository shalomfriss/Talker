import ImageIO
import UIKit
import UniformTypeIdentifiers

private enum BackgroundPhotoPreparation {
    static func preparedData(from image: UIImage, maxPixelSize: CGFloat) -> Data? {
        guard maxPixelSize > 0 else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxPixelSize / max(longestSide, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let result = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return result.jpegData(compressionQuality: 0.8)
    }

    static func preparedData(from data: Data, maxPixelSize: Int, jpegQuality: CGFloat = 0.8) -> Data? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else { return nil }
        return preparedData(from: source, maxPixelSize: maxPixelSize, jpegQuality: jpegQuality)
    }

    static func preparedData(fromFile url: URL, maxPixelSize: Int) -> Data? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithURL(url as CFURL, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else { return nil }
        return preparedData(from: source, maxPixelSize: maxPixelSize)
    }

    private static func preparedData(from source: CGImageSource, maxPixelSize: Int,
                                     jpegQuality: CGFloat = 0.8) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

@MainActor
enum PhotoProcessing {
    nonisolated static func preparedDataAsync(from image: UIImage, maxPixelSize: CGFloat = 1200) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            BackgroundPhotoPreparation.preparedData(from: image, maxPixelSize: maxPixelSize)
        }.value
    }

    nonisolated static func preparedDataAsync(from data: Data, maxPixelSize: Int = 1200,
                                              jpegQuality: CGFloat = 0.8) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            BackgroundPhotoPreparation.preparedData(from: data, maxPixelSize: maxPixelSize,
                                                    jpegQuality: jpegQuality)
        }.value
    }

    nonisolated static func preparedDataAsync(fromFile url: URL, maxPixelSize: Int = 1200) async throws -> Data? {
        try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            return BackgroundPhotoPreparation.preparedData(fromFile: url, maxPixelSize: maxPixelSize)
        }.value
    }

    static func preparedData(from data: Data) -> Data? {
        preparedData(from: data, maxPixelSize: 1200)
    }

    static func preparedData(from data: Data, maxPixelSize: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return preparedData(from: image, maxPixelSize: maxPixelSize)
    }

    static func preparedData(from image: UIImage) -> Data? {
        preparedData(from: image, maxPixelSize: 1200)
    }

    static func preparedData(from image: UIImage, maxPixelSize: CGFloat) -> Data? {
        BackgroundPhotoPreparation.preparedData(from: image, maxPixelSize: maxPixelSize)
    }

    static func textPictureData(_ text: String) -> Data? {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !clean.isEmpty else { return nil }
        let canvas = CGSize(width: 512, height: 512)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [:]
        var textBounds = CGRect.zero
        for size in stride(from: 220, through: 36, by: -8) {
            attributes = [.font: UIFont.systemFont(ofSize: CGFloat(size), weight: .semibold),
                          .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
            textBounds = (clean as NSString).boundingRect(
                with: CGSize(width: 440, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            if textBounds.height <= 440 { break }
        }
        let image = UIGraphicsImageRenderer(size: canvas).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            (clean as NSString).draw(in: CGRect(x: 36, y: max(36, (512 - textBounds.height) / 2),
                                               width: 440, height: min(440, textBounds.height + 8)),
                                     withAttributes: attributes)
        }
        return preparedData(from: image)
    }

    static func symbolPictureData(symbol: String, label: String) -> Data? {
        let cleanSymbol = String(symbol.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        let cleanLabel = String(label.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !cleanSymbol.isEmpty, !cleanLabel.isEmpty else { return nil }
        let canvas = CGSize(width: 512, height: 512)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let symbolAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 222), .paragraphStyle: paragraph
        ]
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 53, weight: .semibold),
            .foregroundColor: UIColor.black, .paragraphStyle: paragraph
        ]
        let image = UIGraphicsImageRenderer(size: canvas).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvas))
            (cleanSymbol as NSString).draw(in: CGRect(x: 32, y: 60, width: 448, height: 280),
                                           withAttributes: symbolAttributes)
            (cleanLabel as NSString).draw(in: CGRect(x: 32, y: 386, width: 448, height: 74),
                                          withAttributes: labelAttributes)
        }
        return preparedData(from: image)
    }
}
