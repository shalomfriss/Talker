import XCTest
import UIKit
@testable import OpenVoice

final class DrawingBoardTests: XCTestCase {
    @MainActor
    func testOnDeviceTextRecognitionReadsRenderedWritingAndRejectsBlankCanvas() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 960, height: 320))
        let writing = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 960, height: 320))
            ("HELLO" as NSString).draw(at: CGPoint(x: 80, y: 75), withAttributes: [
                .font: UIFont.systemFont(ofSize: 150, weight: .black),
                .foregroundColor: UIColor.black
            ])
        }
        let recognized = try DrawingTextRecognition.recognize(imageData: XCTUnwrap(writing.pngData()))
        XCTAssertTrue(recognized.uppercased().contains("HELLO"), recognized)

        let blank = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 960, height: 320))
        }
        XCTAssertThrowsError(try DrawingTextRecognition.recognize(imageData: XCTUnwrap(blank.pngData()))) { error in
            XCTAssertTrue(error is DrawingTextRecognitionError)
        }
    }

    func testPointsStayInsideCanvasAndOldDataHasEmptyDrawing() throws {
        let point = DrawingPoint(CGPoint(x: 400, y: -20), in: CGSize(width: 200, height: 100))
        XCTAssertEqual(point, DrawingPoint(CGPoint(x: 200, y: 0), in: CGSize(width: 200, height: 100)))
        XCTAssertEqual(point.location(in: CGSize(width: 400, height: 200)), CGPoint(x: 400, y: 0))

        let older = StoredData(items: StarterVocabulary.items, routines: [], phrases: [], settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(older)) as? [String: Any])
        object.removeValue(forKey: "drawingStrokes")
        let restored = try JSONDecoder().decode(StoredData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(restored.drawingStrokes.isEmpty)
    }

    @MainActor
    func testDrawingStaysWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: sourceURL)
        let firstProfile = source.activeProfileID
        let stroke = DrawingStroke(points: [DrawingPoint(CGPoint(x: 20, y: 30),
                                                         in: CGSize(width: 200, height: 100))],
                                   ink: .blue, width: 5)
        source.updateDrawing([stroke])
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.drawingStrokes.isEmpty)
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.drawingStrokes, [stroke])
        XCTAssertEqual(CommunicationStore(storageURL: sourceURL).drawingStrokes, [stroke])

        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try target.importBackup(source.backupData())
        XCTAssertEqual(target.drawingStrokes, [stroke])
        target.updateDrawing([])
        XCTAssertTrue(target.drawingStrokes.isEmpty)
    }
}
