import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import OpenVoice

final class PhotoProcessingTests: XCTestCase {
    @MainActor
    func testCapturedPhotoUsesSameBoundedJPEGAsImportedPhoto() throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let prepared = try XCTUnwrap(PhotoProcessing.preparedData(from: original))
        let image = try XCTUnwrap(UIImage(data: prepared))
        XCTAssertEqual(image.size, CGSize(width: 1200, height: 800))
        XCTAssertTrue(prepared.starts(with: Data([0xFF, 0xD8])))
        let imported = try XCTUnwrap(PhotoProcessing.preparedData(from: try XCTUnwrap(original.pngData())))
        XCTAssertEqual(UIImage(data: imported)?.size, image.size)
    }

    @MainActor
    func testCapturedPhotoCanBePreparedOffMainThread() async throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let prepared = await PhotoProcessing.preparedDataAsync(from: original)
        let jpeg = try XCTUnwrap(prepared)
        XCTAssertTrue(jpeg.starts(with: Data([0xFF, 0xD8])))
        XCTAssertEqual(UIImage(data: jpeg)?.size, CGSize(width: 1200, height: 800))
    }

    @MainActor
    func testBackgroundPhotoPreparationKeepsImportBounded() async throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let data = try XCTUnwrap(original.pngData())
        let prepared = await PhotoProcessing.preparedDataAsync(from: data)
        let jpeg = try XCTUnwrap(prepared)
        XCTAssertTrue(jpeg.starts(with: Data([0xFF, 0xD8])))
        XCTAssertEqual(UIImage(data: jpeg)?.size, CGSize(width: 1200, height: 800))
        let invalid = await PhotoProcessing.preparedDataAsync(from: Data("bad image".utf8))
        XCTAssertNil(invalid)
        let preparedPictureWord = await PhotoProcessing.preparedDataAsync(from: data,
                                                                         maxPixelSize: 320)
        let pictureWord = try XCTUnwrap(preparedPictureWord)
        XCTAssertEqual(UIImage(data: pictureWord)?.size, CGSize(width: 320, height: 213))
        XCTAssertLessThan(pictureWord.count, 512 * 1_024)
    }

    @MainActor
    func testFilePhotoPreparationKeepsImportBounded() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(image.pngData()).write(to: url)
        let prepared = try await PhotoProcessing.preparedDataAsync(fromFile: url)
        let jpeg = try XCTUnwrap(prepared)
        XCTAssertTrue(jpeg.starts(with: Data([0xFF, 0xD8])))
        XCTAssertEqual(UIImage(data: jpeg)?.size, CGSize(width: 1200, height: 800))
    }

    @MainActor
    func testBackgroundPhotoPreparationAppliesImageOrientation() async throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let source = try XCTUnwrap(original.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, source, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let prepared = await PhotoProcessing.preparedDataAsync(from: data as Data)
        XCTAssertEqual(UIImage(data: try XCTUnwrap(prepared))?.size,
                       CGSize(width: source.height, height: source.width))
    }
}
