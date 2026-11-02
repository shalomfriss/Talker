import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class PrintableStoryPDFTests: XCTestCase {
    func testVideoPagePrintsPosterAndPlaybackNote() throws {
        let poster = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
        }
        let page = StoryPage(text: "The bus arrives.", symbol: "🚌", videoData: Data([1]),
                             videoPosterData: poster.pngData())
        let story = VisualStory(title: "Going to school", pages: [page])
        let pdf = PrintableStoryPDF.makeData(story: story, paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("video in app") == true)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("The bus arrives") == true)
        XCTAssertGreaterThan(pdf.count, 4_000)
    }

    func testPhotoStoryExportsAllPagesOnLetterAndA4() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 400)).image { context in
            UIColor(red: 0.55, green: 0.78, blue: 0.83, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 400))
            UIColor(red: 0.27, green: 0.54, blue: 0.39, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 285, width: 640, height: 115))
            UIColor(red: 1, green: 0.83, blue: 0.42, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 449, y: 43, width: 83, height: 83))
        }
        let story = VisualStory(title: "A Calm Trip to the Park", pages: [
            StoryPage(text: "First, we get ready to go outside.", imageData: photo.pngData()),
            StoryPage(text: "At the park, I can play or take a quiet break.", symbol: "🌳")
        ])
        for (paperSize, expectedSize) in [
            (PrintableBoardPDF.PaperSize.letter, CGSize(width: 612, height: 792)),
            (.a4, CGSize(width: 595, height: 842))
        ] {
            let data = PrintableStoryPDF.makeData(story: story, paperSize: paperSize)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 2)
            XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, expectedSize)
            XCTAssertTrue(document.page(at: 0)?.string?.contains("First, we get ready") == true)
            XCTAssertTrue(document.page(at: 1)?.string?.contains("quiet break") == true)
            XCTAssertGreaterThan(data.count, 4_000)
            if expectedSize.width == 612 {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
                attachment.name = "Open Voice Story Sample"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testLongStoryPageContinuesWithoutLosingWords() throws {
        let sentence = "We can take a break whenever we need one."
        let story = VisualStory(title: "A Longer Story", pages: [
            StoryPage(text: Array(repeating: sentence, count: 90).joined(separator: " "),
                      symbol: "🌿")
        ])
        let document = try XCTUnwrap(PDFDocument(data: PrintableStoryPDF.makeData(
            story: story, paperSize: .letter)))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            .joined(separator: " ")
        XCTAssertEqual(text.components(separatedBy: "whenever").count - 1, 90)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("continued") == true)
    }
}
