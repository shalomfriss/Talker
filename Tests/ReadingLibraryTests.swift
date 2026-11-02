import XCTest
@testable import OpenVoice

final class ReadingLibraryTests: XCTestCase {
    func testOlderProfileWithoutReadingLibraryStillLoads() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "savedReadingDocuments")
        let restored = try JSONDecoder().decode(StoredData.self,
                                                from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(restored.savedReadingDocuments.isEmpty)
    }

    @MainActor
    func testSavedReadingCanBeReopenedEditedBackedUpAndIsolatedByProfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID

        XCTAssertThrowsError(try store.saveReadingDocument(title: "", pages: ["Hello"]))
        XCTAssertThrowsError(try store.saveReadingDocument(title: "Page", pages: [" "]))
        let id = try store.saveReadingDocument(title: " Letter ", pages: ["First page", "Second page"])
        XCTAssertEqual(store.savedReadingDocuments.first?.title, "Letter")
        XCTAssertEqual(store.savedReadingDocuments.first?.readingDocument.pages, ["First page", "Second page"])
        let updatedID = try store.saveReadingDocument(title: "Revised letter", pages: ["Edited", "Second page"],
                                                      existingID: id)
        XCTAssertEqual(updatedID, id)
        XCTAssertEqual(store.savedReadingDocuments.count, 1)

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.savedReadingDocuments.first?.pages.first, "Edited")
        let backup = try store.backupData()
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.savedReadingDocuments, store.savedReadingDocuments)

        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertTrue(store.savedReadingDocuments.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.savedReadingDocuments.first?.id, id)
        store.deleteReadingDocument(id: id)
        XCTAssertTrue(store.savedReadingDocuments.isEmpty)
    }

    @MainActor
    func testLibrarySizeLimitPreservesSavedTexts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let id = try store.saveReadingDocument(title: "Short", pages: ["Keep this"])
        XCTAssertThrowsError(try store.saveReadingDocument(title: "Long",
                                                            pages: [String(repeating: "a", count: 500_001)])) { error in
            XCTAssertEqual(error as? ReadingLibraryError, .documentTooLong)
        }
        XCTAssertEqual(store.savedReadingDocuments.map(\.id), [id])
    }
}
