import UIKit
import XCTest
@testable import OpenVoice

final class ReadAloudDocumentTests: XCTestCase {
    func testTextFileKeepsReadableContent() throws {
        let data = "Please wait while I explain.\nThen ask me a question.".data(using: .utf16)!
        let document = try ReadAloudDocument.imported(data: data, fileName: "My notes.txt")
        XCTAssertEqual(document.title, "My notes")
        XCTAssertEqual(document.pages, ["Please wait while I explain.\nThen ask me a question."])
    }

    func testPDFKeepsPageOrderAndExtractsSelectableText() throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 500))
        let data = renderer.pdfData { context in
            context.beginPage()
            "Page one: I need a break.".draw(at: CGPoint(x: 24, y: 24),
                                              withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            context.beginPage()
            "Page two: Please explain again.".draw(at: CGPoint(x: 24, y: 24),
                                                     withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
        }
        let document = try ReadAloudDocument.imported(data: data, fileName: "Instructions.pdf")
        XCTAssertEqual(document.title, "Instructions")
        XCTAssertEqual(document.pages.count, 2)
        XCTAssertTrue(document.pages[0].contains("I need a break"))
        XCTAssertTrue(document.pages[1].contains("Please explain again"))
    }

    func testImagePageUsesOnDeviceTextRecognition() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 180)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 180))
            "Please speak slowly".draw(at: CGPoint(x: 30, y: 50),
                                       withAttributes: [.font: UIFont.systemFont(ofSize: 54),
                                                        .foregroundColor: UIColor.black])
        }
        let document = try ReadAloudDocument.imported(data: image.pngData()!, fileName: "Page.png")
        XCTAssertTrue(document.pages[0].localizedCaseInsensitiveContains("Please speak slowly"))
    }

    func testScannedPDFPageUsesOnDeviceTextRecognition() throws {
        let bounds = CGRect(x: 0, y: 0, width: 900, height: 180)
        let image = UIGraphicsImageRenderer(size: bounds.size).image { context in
            UIColor.white.setFill()
            context.fill(bounds)
            "Please speak slowly".draw(at: CGPoint(x: 30, y: 50),
                                       withAttributes: [.font: UIFont.systemFont(ofSize: 54),
                                                        .foregroundColor: UIColor.black])
        }
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            image.draw(in: bounds)
        }
        let document = try ReadAloudDocument.imported(data: data, fileName: "Scanned instructions.pdf")
        XCTAssertTrue(document.pages[0].localizedCaseInsensitiveContains("Please speak slowly"))
    }
}
