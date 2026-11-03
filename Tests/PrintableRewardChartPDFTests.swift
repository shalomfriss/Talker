import PDFKit
import XCTest
@testable import OpenVoice

final class PrintableRewardChartPDFTests: XCTestCase {
    @MainActor
    func testRewardChartPrintsCurrentProgressOnLetterAndA4() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240)).image { context in
            UIColor(red: 0.22, green: 0.39, blue: 0.68, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            ("♫" as NSString).draw(in: CGRect(x: 36, y: 27, width: 168, height: 170),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 150),
                                                     .foregroundColor: UIColor.white])
        }
        let chart = RewardChart(title: "Morning practice", reward: "Choose a favorite song together",
                                symbol: "🎵", targetTokens: 20, earnedTokens: 7,
                                photoData: try XCTUnwrap(image.pngData()))
        for paperSize in [PrintableBoardPDF.PaperSize.letter, .a4] {
            let data = PrintableRewardChartPDF.makeData(chart: chart,
                                                        profileName: "Alex Rivera",
                                                        paperSize: paperSize)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size,
                           paperSize.bounds.size)
            let text = try XCTUnwrap(document.page(at: 0)?.string)
            XCTAssertTrue(text.contains("Morning practice"))
            XCTAssertTrue(text.contains("Choose a favorite song together"))
            XCTAssertTrue(text.contains("Alex Rivera"))
            XCTAssertTrue(text.contains("7 of 20 stars earned"))
            XCTAssertTrue(text.contains("Progress at print time"))
            XCTAssertTrue(text.contains("20"))
            if paperSize == .letter {
                let sampleURL = FileManager.default.urls(for: .documentDirectory,
                                                         in: .userDomainMask)[0]
                    .appendingPathComponent("printable-reward-chart-sample.pdf")
                try data.write(to: sampleURL, options: .atomic)
            }
        }
    }

    @MainActor
    func testOneTokenChartAndSpanishInstructionsRemainPrintable() throws {
        let chart = RewardChart(title: "Mi meta", reward: "Elegir música",
                                targetTokens: 1, earnedTokens: 0)
        let data = PrintableRewardChartPDF.makeData(chart: chart,
                                                    profileName: "María", language: "es",
                                                    paperSize: .a4)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(document.pageCount, 1)
        let text = try XCTUnwrap(document.page(at: 0)?.string)
        XCTAssertTrue(text.contains("Mi meta"))
        XCTAssertTrue(text.contains("Elegir música"))
        XCTAssertTrue(text.contains("0 de 1 estrellas ganadas"))
        XCTAssertTrue(text.contains("Marca un espacio vacío"))
    }
}
