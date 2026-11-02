import XCTest
@testable import OpenVoice

final class BulkVocabularyTests: XCTestCase {
    func testSpokenButtonNamesBecomeAnEditableList() {
        XCTAssertEqual(BulkVocabulary.editableList(from: "Water next button Bathroom, Help; More please"),
                       "Water\nBathroom\nHelp\nMore please")
        XCTAssertEqual(BulkVocabulary.editableList(from: "  I need a break  "), "I need a break")
    }

    func testPreviewParsesListsSymbolsMessagesAndDuplicateCounts() {
        let preview = BulkVocabulary.preview(
            "want, water, Water\nCustom | 🐱 | I want my cat\n| 🐶 | missing label",
            board: "Core", existing: StarterVocabulary.items)
        XCTAssertEqual(preview.entries, [
            BulkVocabularyEntry(label: "water", symbol: "💧", message: "water"),
            BulkVocabularyEntry(label: "Custom", symbol: "🐱", message: "I want my cat")
        ])
        XCTAssertEqual(preview.existingCount, 1)
        XCTAssertEqual(preview.repeatedCount, 1)
        XCTAssertEqual(preview.invalidCount, 1)
        XCTAssertTrue(preview.canAdd)
    }

    func testPreviewRejectsOversizedListsWithoutPartialCommit() {
        let many = (0...BulkVocabulary.maximumEntries).map { "Word \($0)" }.joined(separator: ",")
        let preview = BulkVocabulary.preview(many, board: "Core", existing: [])
        XCTAssertEqual(preview.entries.count, BulkVocabulary.maximumEntries)
        XCTAssertTrue(preview.exceedsLimit)
        XCTAssertFalse(preview.canAdd)
        let long = BulkVocabulary.preview(String(repeating: "a", count: BulkVocabulary.maximumInputCharacters + 1),
                                          board: "Core", existing: [])
        XCTAssertTrue(long.inputTooLong)
        XCTAssertFalse(long.canAdd)
    }

    @MainActor
    func testBulkButtonsStayOrderedOnTheirBoardAndSurviveBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Pets"))
        let preview = BulkVocabulary.preview(
            "Cat | 🐈 | I want my cat\nDog | 🐕 | I want my dog\ncat",
            board: "Pets", existing: store.items)
        XCTAssertEqual(preview.entries.count, 2)
        XCTAssertEqual(preview.repeatedCount, 1)
        XCTAssertEqual(store.addBulkItems(preview.entries, to: "Pets", backgroundColorHex: "#DFF8E8"), 2)
        XCTAssertEqual(store.items.filter { $0.category == "Pets" }.map(\.label), ["Cat", "Dog"])
        XCTAssertEqual(store.items.first(where: { $0.category == "Pets" })?.message, "I want my cat")
        XCTAssertNotNil(store.items.first(where: { $0.category == "Pets" })?.backgroundColorHex)
        XCTAssertEqual(store.addBulkItems(preview.entries, to: "Pets"), 0)
        XCTAssertEqual(store.addBulkItems(preview.entries, to: "Unknown"), 0)

        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Second"))
        XCTAssertFalse(store.items.contains { $0.category == "Pets" })
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.items.filter { $0.category == "Pets" }.map(\.label), ["Cat", "Dog"])
        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.items.filter { $0.category == "Pets" }.map(\.label), ["Cat", "Dog"])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.filter { $0.category == "Pets" }.map(\.label), ["Cat", "Dog"])
    }

    @MainActor
    func testQuickBoardCreatesBoardAndButtonsTogether() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("quick.json")
        let store = CommunicationStore(storageURL: file)
        let entries = BulkVocabulary.preview("Water\nI need a break", board: "Quick needs", existing: store.items).entries
        XCTAssertEqual(store.addBulkBoard(" Quick needs ", entries: entries), 2)
        XCTAssertEqual(store.items.filter { $0.category == "Quick needs" }.map(\.label),
                       ["Water", "I need a break"])
        XCTAssertEqual(store.addBulkBoard("quick needs", entries: entries), 0)
        XCTAssertEqual(store.addBulkBoard("Empty", entries: []), 0)
        XCTAssertFalse(store.categories.contains("Empty"))
        XCTAssertEqual(CommunicationStore(storageURL: file).items.filter { $0.category == "Quick needs" }.count, 2)
    }
}
