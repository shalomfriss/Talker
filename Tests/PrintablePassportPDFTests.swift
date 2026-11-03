import PDFKit
import XCTest
@testable import OpenVoice

final class PrintablePassportPDFTests: XCTestCase {
    @MainActor
    func testPassportPDFIncludesChosenEntriesOnLetterAndA4() throws {
        let passport = CommunicationPassport(
            name: "Alex Rivera",
            introduction: "I like meeting new people.",
            communicationMethods: "I use an AAC board and sometimes write my answer.",
            helpfulSupport: "Please give me time to finish my message.",
            boundaries: "Please ask me before touching my device.",
            whenOverwhelmed: "A quiet place helps me.",
            interests: "Trains and gardening")

        for paperSize in [PrintableBoardPDF.PaperSize.letter, .a4] {
            let data = PrintablePassportPDF.makeData(passport: passport, paperSize: paperSize)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size,
                           paperSize.bounds.size)
            let text = try XCTUnwrap(document.page(at: 0)?.string)
            for entry in passport.entries {
                XCTAssertTrue(text.contains(entry.value), entry.title)
            }
            XCTAssertFalse(text.contains("Open Voice - no passport"))
        }

        let sample = PrintablePassportPDF.makeData(passport: passport, paperSize: .letter)
        let sampleURL = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
            .appendingPathComponent("communication-passport-sample.pdf")
        try sample.write(to: sampleURL, options: .atomic)
    }

    @MainActor
    func testLongPassportEntryContinuesWithoutLosingTheEnd() throws {
        let longIntroduction = String(repeating: "I choose when to share this information. ", count: 90)
            + "My final request is to wait for my answer."
        let passport = CommunicationPassport(
            name: "Morgan",
            introduction: longIntroduction,
            communicationMethods: "I point to words.",
            helpfulSupport: "Wait and listen.")
        let data = PrintablePassportPDF.makeData(passport: passport, paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        let allText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        XCTAssertTrue(allText.contains("My final request is to wait for my answer."))
        XCTAssertTrue(allText.contains("I point to words."))
        XCTAssertTrue(allText.contains("Wait and listen."))
        XCTAssertTrue(allText.contains("(CONTINUED)"))
    }
}
