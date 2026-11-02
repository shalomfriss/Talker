import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class PictureMessagePDFTests: XCTestCase {
    func testPictureMessagePDFKeepsPhotosSymbolsAndTextOnLetterAndA4() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { context in
            UIColor(red: 0.44, green: 0.70, blue: 0.80, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
            UIColor(red: 0.31, green: 0.53, blue: 0.36, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 140, width: 300, height: 60))
        }
        let tokens = [
            PictureMessageToken(text: "I", symbol: "🙋", imageData: nil),
            PictureMessageToken(text: "want water", symbol: "💧", imageData: nil),
            PictureMessageToken(text: "at the park", symbol: nil, imageData: photo.pngData()),
            PictureMessageToken(text: "please", symbol: nil, imageData: nil)
        ]
        for (paperSize, expectedSize) in [
            (PrintableBoardPDF.PaperSize.letter, CGSize(width: 612, height: 792)),
            (.a4, CGSize(width: 595, height: 842))
        ] {
            let data = PictureMessagePDF.makeData(tokens: tokens, paperSize: paperSize)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, expectedSize)
            let text = try XCTUnwrap(document.page(at: 0)?.string)
            XCTAssertTrue(text.contains("want water"))
            XCTAssertTrue(text.contains("at the park"))
            XCTAssertTrue(text.contains("please"))
            XCTAssertGreaterThan(data.count, 4_000)
            if expectedSize.width == 612 {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
                attachment.name = "Open Voice Picture Message Sample"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testLongPictureMessagePaginatesWithoutLosingWords() throws {
        let longText = Array(repeating: "quiet", count: 210).joined(separator: " ")
        let tokens = [PictureMessageToken(text: longText, symbol: "🌿", imageData: nil)]
            + (0..<18).map { index in
                PictureMessageToken(text: "TOKEN\(index)", symbol: "💬", imageData: nil)
            }
        let data = PictureMessagePDF.makeData(tokens: tokens, language: "es", paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            .joined(separator: " ")
        XCTAssertEqual(text.components(separatedBy: "quiet").count - 1, 210)
        for index in 0..<18 { XCTAssertTrue(text.contains("TOKEN\(index)")) }
        XCTAssertTrue(text.contains("MENSAJE CON IMÁGENES"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Open Voice Long Picture Message"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
