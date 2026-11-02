import XCTest
@testable import OpenVoice

final class PaintBoardTests: XCTestCase {
    @MainActor
    func testPaintingSeveralButtonsChangesOnlyTheirBackground() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let want = try XCTUnwrap(store.items.first { $0.category == "Core" && $0.label == "want" })
        let need = try XCTUnwrap(store.items.first { $0.category == "Core" && $0.label == "need" })
        let untouched = try XCTUnwrap(store.items.first { $0.category == "Core" && $0.id != want.id && $0.id != need.id })
        XCTAssertTrue(store.setButtonBackgroundColor("#fff2a6", for: want.id))
        XCTAssertTrue(store.setButtonBackgroundColor("rgb(255, 242, 166)", for: need.id))
        XCTAssertEqual(store.items.first { $0.id == want.id }?.backgroundColorHex, "#FFF2A6")
        XCTAssertEqual(store.items.first { $0.id == need.id }?.backgroundColorHex, "#FFF2A6")
        XCTAssertEqual(store.items.first { $0.id == want.id }?.message, want.message)
        XCTAssertEqual(store.items.first { $0.id == need.id }?.symbol, need.symbol)
        XCTAssertEqual(store.items.first { $0.id == untouched.id }?.backgroundColorHex, untouched.backgroundColorHex)
        XCTAssertFalse(store.setButtonBackgroundColor("#FFF2A6", for: want.id))
        XCTAssertTrue(store.setButtonBackgroundColor(nil, for: want.id))
        XCTAssertNil(store.items.first { $0.id == want.id }?.backgroundColorHex)
    }

    @MainActor
    func testPaintPersistsThroughRelaunchProfileSwitchBackupAndSelectedImport() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.json")
        let source = CommunicationStore(storageURL: url)
        let water = try XCTUnwrap(source.items.first { $0.category == "Needs" && $0.label == "water" })
        XCTAssertTrue(source.setButtonBackgroundColor("#B7DFFD", for: water.id))
        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertNil(source.items.first { $0.label == "water" }?.backgroundColorHex)
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.items.first { $0.id == water.id }?.backgroundColorHex, "#B7DFFD")
        XCTAssertEqual(CommunicationStore(storageURL: url).items.first { $0.id == water.id }?.backgroundColorHex,
                       "#B7DFFD")
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.items.first { $0.id == water.id }?.backgroundColorHex, "#B7DFFD")
        let added = CommunicationStore(storageURL: directory.appendingPathComponent("added.json"))
        let names = try added.addBoards(fromBackup: source.backupData(), selectedBoards: ["Needs"])
        let importedName = try XCTUnwrap(names.first)
        XCTAssertEqual(added.items.first { $0.category == importedName && $0.label == "water" }?.backgroundColorHex,
                       "#B7DFFD")
    }

    @MainActor
    func testInvalidColorsAndUnknownButtonsAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        let item = try XCTUnwrap(store.items.first)
        XCTAssertFalse(store.setButtonBackgroundColor("not-a-color", for: item.id))
        XCTAssertFalse(store.setButtonBackgroundColor("#12", for: item.id))
        XCTAssertFalse(store.setButtonBackgroundColor("#123456", for: UUID()))
        XCTAssertNil(store.items.first { $0.id == item.id }?.backgroundColorHex)
    }
}
