import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class PrintableRoutinePDFTests: XCTestCase {
    func testRoutinePDFIncludesFirstThenPhotoInstructionsAndStatusOnLetterAndA4() throws {
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 160)).image { context in
            UIColor(red: 0.38, green: 0.68, blue: 0.75, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
            UIColor(red: 0.87, green: 0.67, blue: 0.37, alpha: 1).setFill()
            context.fill(CGRect(x: 35, y: 45, width: 170, height: 80))
        }
        let steps = [
            RoutineStep(title: "Get dressed", symbol: "👕", durationSeconds: 300),
            RoutineStep(title: "Eat breakfast", symbol: "🥣", imageData: photo.pngData(),
                        spokenText: "Sit at the table for breakfast"),
            RoutineStep(title: "Pack my bag", symbol: "🎒", isComplete: true)
        ]
        for (paper, expectedSize) in [
            (PrintableBoardPDF.PaperSize.letter, CGSize(width: 612, height: 792)),
            (.a4, CGSize(width: 595, height: 842))
        ] {
            let data = PrintableRoutinePDF.makeData(profileName: "Avery", steps: steps,
                                                    paperSize: paper)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, expectedSize)
            let text = try XCTUnwrap(document.page(at: 0)?.string)
            for expected in ["Avery", "FIRST", "THEN", "Get dressed", "Eat breakfast",
                             "Sit at the table for breakfast", "Pack my bag", "5 min", "Done"] {
                XCTAssertTrue(text.contains(expected), "Missing \(expected)")
            }
            XCTAssertGreaterThan(data.count, 4_000)
            if expectedSize.width == 612 {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
                attachment.name = "Open Voice Routine Sample"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testLongRoutinePaginatesWithoutLosingInstructions() throws {
        let repeated = Array(repeating: "slowly", count: 120).joined(separator: " ")
        let steps = [RoutineStep(title: "Begin gently", symbol: "🌿", spokenText: repeated)]
            + (0..<22).map { index in
                RoutineStep(title: "ROUTINESTEP\(index)", symbol: "⭐️",
                            durationSeconds: 60, spokenText: "Instruction number \(index)")
            }
        let data = PrintableRoutinePDF.makeData(profileName: "Alex", steps: steps,
                                                language: "es", paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 2)
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
            .joined(separator: " ")
        XCTAssertEqual(text.components(separatedBy: "slowly").count - 1, 120)
        for index in 0..<22 {
            XCTAssertTrue(text.contains("ROUTINESTEP\(index)"))
            XCTAssertTrue(text.contains("Instruction number \(index)"))
        }
        XCTAssertTrue(text.contains("PRIMERO / DESPUÉS"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "Open Voice Long Routine"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testVideoStepPrintsPosterAndPlaybackNote() throws {
        let poster = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let step = RoutineStep(title: "Watch the bus", symbol: "🚌", videoData: Data([1]),
                               videoPosterData: poster, choiceBoardID: UUID())
        let document = try XCTUnwrap(PDFDocument(data: PrintableRoutinePDF.makeData(
            profileName: "Avery", steps: [step], paperSize: .letter)))
        let text = try XCTUnwrap(document.page(at: 0)?.string)
        XCTAssertTrue(text.contains("Watch the bus"))
        XCTAssertTrue(text.contains("Video in app"))
        XCTAssertTrue(text.contains("Choices in app"))
        XCTAssertTrue(text.contains("audio and video play in the app"))
    }
}
