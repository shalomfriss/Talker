import UIKit
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
}
