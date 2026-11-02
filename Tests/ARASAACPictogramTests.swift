import PDFKit
import UIKit
import XCTest
@testable import OpenVoice

final class ARASAACPictogramTests: XCTestCase {
    @MainActor
    func testSearchURLAndOfficialResponseShape() throws {
        XCTAssertEqual(ARASAACPictogramService.searchURL(query: "water bottle", language: "en")?.absoluteString,
                       "https://api.arasaac.org/v1/pictograms/en/search/water%20bottle")
        XCTAssertNil(ARASAACPictogramService.searchURL(query: "   ", language: "en"))
        XCTAssertNil(ARASAACPictogramService.searchURL(query: "water", language: "xx"))
        XCTAssertEqual(ARASAACPictogramService.imageURL(id: 32464, size: 300)?.absoluteString,
                       "https://static.arasaac.org/pictograms/32464/32464_300.png")
        XCTAssertNil(ARASAACPictogramService.imageURL(id: -1, size: 300))
        let result = try JSONDecoder().decode([ARASAACPictogram].self, from: Data(
            #"[{"_id":32464,"keywords":[{"keyword":"water","type":2}]}]"#.utf8))
        XCTAssertEqual(result.first?.id, 32464)
        XCTAssertEqual(result.first?.title, "water")
    }

    @MainActor
    func testPictogramSourceSurvivesStorageTransfersAndCreditsPrintedMaterial() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }.pngData()!
        store.addItem(label: "Water symbol", symbol: "💧", message: "water", category: "Core",
                      imageData: image, arasaacPictogramID: 32464)
        let item = try XCTUnwrap(store.items.first { $0.label == "Water symbol" })
        XCTAssertEqual(item.arasaacPictogramID, 32464)
        XCTAssertTrue(store.addPhrase("I need water."))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "I need water." })
        XCTAssertTrue(store.setPhraseAppearance(phrase, imageData: image, colorHex: nil,
                                                arasaacPictogramID: 32464))

        let reopened = CommunicationStore(storageURL: file)
        XCTAssertEqual(reopened.items.first { $0.id == item.id }?.arasaacPictogramID, 32464)
        XCTAssertEqual(reopened.phrases.first { $0.id == phrase.id }?.arasaacPictogramID, 32464)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.id == item.id }?.arasaacPictogramID, 32464)

        let phraseFile = try PhraseCollectionTransfer.exportData(store.phrases, named: "Water")
        let imported = try PhraseCollectionTransfer.importData(phraseFile)
        XCTAssertEqual(imported.phrases.first { $0.id == phrase.id }?.arasaacPictogramID, 32464)
        let boardData = try OpenBoardFormat.exportBoard(name: "Core", items: [item], language: "en")
        let board = try XCTUnwrap(JSONSerialization.jsonObject(with: boardData) as? [String: Any])
        let buttons = try XCTUnwrap(board["buttons"] as? [[String: Any]])
        let images = try XCTUnwrap(board["images"] as? [[String: Any]])
        XCTAssertEqual(buttons.first?["ext_openvoice_arasaac_pictogram_id"] as? Int, 32464)
        XCTAssertTrue((images.first?["ext_openvoice_attribution"] as? String ?? "").contains("Sergio Palao"))
        let roundTrip = try OpenBoardFormat.importData(boardData, fileExtension: "obf")
        XCTAssertEqual(roundTrip.items.first?.arasaacPictogramID, 32464)

        let printable = PrintableBoardPDF.makeData(profileName: "My Voice", categories: ["Core"],
                                                   items: [item])
        XCTAssertTrue((PDFDocument(data: printable)?.string ?? "").contains("Sergio Palao"))
        let pictureMessage = PictureMessagePDF.makeData(tokens: [
            PictureMessageToken(text: "water", symbol: "💧", imageData: image,
                                arasaacPictogramID: 32464)
        ])
        XCTAssertTrue((PDFDocument(data: pictureMessage)?.string ?? "").contains("Sergio Palao"))
    }
}
