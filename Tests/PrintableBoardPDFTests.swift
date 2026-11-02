import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class PrintableBoardPDFTests: XCTestCase {
    func testAllBoardsRenderWithPageReferencesAndNoLostItems() throws {
        let core = (1...17).map { number in
            CommunicationItem(label: "word \(number)", symbol: "💬", message: "word \(number)",
                              category: "Core")
        }
        let link = CommunicationItem(label: "Visit Needs", symbol: "➡️", message: "Visit Needs",
                                     category: "Core", destinationBoard: "Needs")
        let needs = CommunicationItem(label: "water", symbol: "💧", message: "water", category: "Needs")
        let data = PrintableBoardPDF.makeData(profileName: "Taylor", categories: ["Core", "Needs", "Empty"],
                                              items: core + [link, needs], paperSize: .letter)
        let document = PDFDocument(data: data)

        XCTAssertNotNil(document)
        XCTAssertEqual(document?.pageCount, 4)
        XCTAssertTrue(document?.page(at: 0)?.string?.contains("Taylor") == true)
        XCTAssertTrue(document?.page(at: 0)?.string?.contains("word 1") == true)
        XCTAssertTrue(document?.page(at: 1)?.string?.contains("word 17") == true)
        XCTAssertTrue(document?.page(at: 1)?.string?.contains("To Needs - p. 3") == true)
        XCTAssertTrue(document?.page(at: 2)?.string?.contains("water") == true)
        XCTAssertTrue(document?.page(at: 3)?.string?.contains("Write or attach words") == true)
        try data.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenVoicePaginationTest.pdf"), options: .atomic)
    }

    func testCustomPhotoRendersIntoPDF() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let item = CommunicationItem(label: "My photo", symbol: "", message: "My photo",
                                     category: "Core", imageData: image.pngData())
        let data = PrintableBoardPDF.makeData(profileName: "Taylor", categories: ["Core"],
                                              items: [item], paperSize: .a4)
        let page = PDFDocument(data: data)?.page(at: 0)

        XCTAssertEqual(page?.bounds(for: .mediaBox).size, CGSize(width: 595, height: 842))
        XCTAssertTrue(page?.string?.contains("My photo") == true)
        XCTAssertGreaterThan(data.count, 3_000)
        try data.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenVoicePhotoTest.pdf"), options: .atomic)
    }

    func testStarterBoardsCreateVisualReviewSample() throws {
        let data = PrintableBoardPDF.makeData(profileName: "My Voice",
                                              categories: StarterVocabulary.categories,
                                              items: StarterVocabulary.items,
                                              choiceBoards: StarterVocabulary.choiceBoards,
                                              paperSize: .letter)
        let document = PDFDocument(data: data)
        XCTAssertEqual(document?.pageCount, 13)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OpenVoiceStarterBoards.pdf")
        try data.write(to: url, options: .atomic)
    }

    func testSpanishBoardsPrintTranslatedWordsAndChoices() throws {
        let personal = CommunicationItem(label: "my dog", symbol: "🐕", message: "my dog",
                                         category: "Core", isCustom: true)
        let items = StarterVocabulary.items + [personal]
        var translations = StarterTranslations.forItems(items)
        translations[personal.id.uuidString] = ["es": WordTranslation(label: "mi perro", message: "mi perro")]
        let data = PrintableBoardPDF.makeData(profileName: "Mi voz",
                                              categories: StarterVocabulary.categories,
                                              items: items,
                                              choiceBoards: StarterVocabulary.choiceBoards,
                                              language: "es",
                                              wordTranslations: translations,
                                              paperSize: .letter)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 13)
        let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }
        let normalizedText = pages.joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(pages.joined().contains("sí"))
        XCTAssertTrue(pages.joined().contains("mi perro"))
        XCTAssertTrue(normalizedText.contains("me duele cuando me tocan"))
        XCTAssertTrue(pages[11].contains("Otra cosa"))
        XCTAssertTrue(pages[11].contains("No, gracias"))
        XCTAssertTrue(pages[11].contains("Señala una opción"))
        try data.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenVoiceSpanishBoards.pdf"), options: .atomic)
    }

    func testUnlistedBoardStillExportsItsWords() {
        let item = CommunicationItem(label: "custom", symbol: "⭐️", message: "custom",
                                     category: "Personal")
        let data = PrintableBoardPDF.makeData(profileName: "Taylor", categories: ["Core"],
                                              items: [item], paperSize: .letter)
        let document = PDFDocument(data: data)
        XCTAssertEqual(document?.pageCount, 2)
        XCTAssertTrue(document?.page(at: 1)?.string?.contains("custom") == true)
    }

    func testChoiceBoardPrintsOptionsAndWaysToDecline() {
        let board = ChoiceBoard(title: "What for lunch?", options: [
            ChoiceOption(label: "Soup", symbol: "🥣"),
            ChoiceOption(label: "Rice", symbol: "🍚")
        ])
        let data = PrintableBoardPDF.makeData(profileName: "Taylor", categories: ["Core"],
                                              items: [], choiceBoards: [board], paperSize: .letter)
        let document = PDFDocument(data: data)
        XCTAssertEqual(document?.pageCount, 2)
        let page = document?.page(at: 1)?.string ?? ""
        XCTAssertTrue(page.contains("What for lunch?"))
        XCTAssertTrue(page.contains("Soup"))
        XCTAssertTrue(page.contains("Rice"))
        XCTAssertTrue(page.contains("Something else"))
        XCTAssertTrue(page.contains("No thanks"))
    }
}
