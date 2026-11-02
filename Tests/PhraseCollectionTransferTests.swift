import UIKit
import XCTest
@testable import OpenVoice

final class PhraseCollectionTransferTests: XCTestCase {
    @MainActor
    func testFolderFileRoundTripKeepsOrderPicturesRecordingsLabelsAndProfileIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.addPhrase("I need water.", folder: "Needs", shortcut: "water",
                                       label: "💧 Water"))
        XCTAssertTrue(source.addPhrase("Please wait for me.", folder: "Social"))
        XCTAssertTrue(source.addPhrase("I need a quiet place.", folder: "Needs", label: "Quiet"))
        let water = try XCTUnwrap(source.phrases.first { $0.text == "I need water." })
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        XCTAssertTrue(source.setPhraseAppearance(water, imageData: try XCTUnwrap(photo.pngData()),
                                                 colorHex: "#ddeeff"))
        let recording = try XCTUnwrap(ScanCueSound.wavData(for: .blip))
        source.updatePhraseRecording(water, audioData: recording)
        let selected = source.phrases.filter { $0.folder == "Needs" }
        let data = try PhraseCollectionTransfer.exportData(selected, named: "Needs")
        let file = try PhraseCollectionTransfer.importData(data)
        XCTAssertEqual(file.name, "Needs")
        XCTAssertEqual(file.phrases.map(\.text), ["I need water.", "I need a quiet place."])
        XCTAssertEqual(file.counts(against: []).new, 2)

        let targetURL = directory.appendingPathComponent("target.json")
        let target = CommunicationStore(storageURL: targetURL)
        let firstProfile = target.activeProfileID
        let result = target.importPhraseCollection(file, mode: .addMissing)
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.omittedPictures, 0)
        XCTAssertEqual(result.omittedRecordings, 0)
        XCTAssertEqual(target.phrases.filter { $0.folder == "Needs" }.map(\.text), file.phrases.map(\.text))
        let imported = try XCTUnwrap(target.phrases.first { $0.text == "I need water." })
        XCTAssertNotEqual(imported.id, water.id)
        XCTAssertEqual(imported.label, "💧 Water")
        XCTAssertEqual(imported.shortcut, "water")
        XCTAssertEqual(imported.colorHex, "#DDEEFF")
        XCTAssertNotNil(imported.imageData.flatMap(UIImage.init(data:)))
        XCTAssertEqual(imported.audioData, recording)
        XCTAssertEqual(target.importPhraseCollection(file, mode: .addMissing).skipped, 2)
        XCTAssertEqual(CommunicationStore(storageURL: targetURL).phrases.first {
            $0.text == "I need water."
        }?.label, "💧 Water")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(target.backupData())
        XCTAssertEqual(restored.phrases.first { $0.text == "I need water." }?.audioData, recording)
        XCTAssertTrue(target.addProfile("Other communicator"))
        XCTAssertFalse(target.phrases.contains { $0.text == "I need water." })
        XCTAssertTrue(target.switchProfile(to: firstProfile))
        XCTAssertEqual(target.phrases.first { $0.text == "I need water." }?.label, "💧 Water")
    }

    @MainActor
    func testUpdatingMatchesKeepsIdentityAndPositionAndClearsConflictingShortcut() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        XCTAssertTrue(target.addPhrase("I need water.", folder: "Needs", shortcut: "water"))
        XCTAssertTrue(target.addPhrase("I need quiet.", folder: "Needs", shortcut: "quiet"))
        let old = try XCTUnwrap(target.phrases.first { $0.text == "I need water." })
        let oldIndex = try XCTUnwrap(target.phrases.firstIndex(where: { $0.id == old.id }))
        let incoming = [
            SavedPhrase(text: "I need water.", label: "💧 Drink", folder: "Drinks", shortcut: "quiet"),
            SavedPhrase(text: "Please wait.", label: "Wait", folder: "Social", shortcut: "wait"),
            SavedPhrase(text: "Please wait.", label: "Again", folder: "Social")
        ]
        let file = try PhraseCollectionTransfer.importData(
            PhraseCollectionTransfer.exportData(incoming, named: "Shared"))
        let counts = file.counts(against: target.phrases)
        XCTAssertEqual(counts.new, 1)
        XCTAssertEqual(counts.matching, 1)
        XCTAssertEqual(counts.repeated, 1)
        let result = target.importPhraseCollection(file, mode: .updateMatching)
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.clearedShortcuts, 1)
        XCTAssertEqual(target.phrases[oldIndex].id, old.id)
        XCTAssertEqual(target.phrases[oldIndex].label, "💧 Drink")
        XCTAssertEqual(target.phrases[oldIndex].folder, "Drinks")
        XCTAssertNil(target.phrases[oldIndex].shortcut)
        XCTAssertEqual(target.phrases.first { $0.text == "I need quiet." }?.shortcut, "quiet")
        XCTAssertEqual(target.phrases.filter { $0.text == "Please wait." }.count, 1)
        XCTAssertEqual(target.phrases.last?.shortcut, "wait")
    }

    @MainActor
    func testUnsupportedOrInvalidPhraseFilesCannotChangeTheProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let before = store.phrases
        XCTAssertThrowsError(try PhraseCollectionTransfer.importData(store.backupData()))
        XCTAssertThrowsError(try PhraseCollectionTransfer.importData(Data("broken".utf8)))
        XCTAssertThrowsError(try PhraseCollectionTransfer.exportData([], named: "Empty"))
        let tooLong = SavedPhrase(text: "I need help.", label: String(repeating: "x", count: 41))
        XCTAssertThrowsError(try PhraseCollectionTransfer.importData(
            PhraseCollectionTransfer.exportData([tooLong], named: "Invalid")))
        XCTAssertEqual(store.phrases, before)
    }
}
