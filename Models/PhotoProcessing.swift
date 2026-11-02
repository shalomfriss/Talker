import UIKit

@MainActor
enum PhotoProcessing {
    static func preparedData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return preparedData(from: image)
    }

    static func preparedData(from image: UIImage) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, 1200 / max(longestSide, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let result = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return result.jpegData(compressionQuality: 0.8)
    }
}
