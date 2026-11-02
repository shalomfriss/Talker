import UIKit
import XCTest
@testable import OpenVoice

final class SavedPhraseAppearanceTests: XCTestCase {
    func testOlderPhraseWithoutAppearanceStillDecodes() throws {
        let phrase = try JSONDecoder().decode(SavedPhrase.self,
            from: Data("{\"text\":\"Please wait\"}".utf8))
        XCTAssertNil(phrase.imageData)
        XCTAssertNil(phrase.colorHex)
    }

    @MainActor
    func testPictureAndColorSurviveEditingRelaunchProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.addPhrase("Please give me a break"))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "Please give me a break" })
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 900)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1800, height: 900))
        }
        XCTAssertTrue(store.setPhraseAppearance(phrase, imageData: try XCTUnwrap(photo.pngData()),
                                                colorHex: "#ddeeff"))
        let decorated = try XCTUnwrap(store.phrases.first { $0.id == phrase.id })
        XCTAssertEqual(decorated.colorHex, "#DDEEFF")
        let picture = try XCTUnwrap(decorated.imageData.flatMap(UIImage.init(data:)))
        XCTAssertLessThanOrEqual(max(picture.size.width, picture.size.height), 1200)

        XCTAssertTrue(store.updatePhraseDetails(phrase, text: "Please give me a short break", shortcut: nil))
        XCTAssertEqual(store.phrases.first { $0.id == phrase.id }?.imageData, decorated.imageData)
        XCTAssertEqual(store.phrases.first { $0.id == phrase.id }?.colorHex, "#DDEEFF")
        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.phrases.first { $0.id == phrase.id }?.imageData, decorated.imageData)
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.colorHex, "#DDEEFF")
        XCTAssertEqual(restored.phrases.first { $0.id == phrase.id }?.imageData, decorated.imageData)

        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertFalse(store.phrases.contains { $0.id == phrase.id })
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertTrue(store.setPhraseAppearance(phrase, imageData: nil, colorHex: nil))
        XCTAssertNil(store.phrases.first { $0.id == phrase.id }?.imageData)
        XCTAssertNil(store.phrases.first { $0.id == phrase.id }?.colorHex)
    }

    @MainActor
    func testUnreadablePictureAndInvalidColorLeavePhraseUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(store.addPhrase("My new phrase"))
        let phrase = try XCTUnwrap(store.phrases.first { $0.text == "My new phrase" })
        XCTAssertFalse(store.setPhraseAppearance(phrase, imageData: Data("bad".utf8), colorHex: nil))
        XCTAssertFalse(store.setPhraseAppearance(phrase, imageData: nil, colorHex: "not a color"))
        XCTAssertNil(store.phrases.first { $0.id == phrase.id }?.imageData)
        XCTAssertNil(store.phrases.first { $0.id == phrase.id }?.colorHex)
    }
}
