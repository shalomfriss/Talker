import XCTest
@testable import OpenVoice

final class SelectedBackupBoardsTests: XCTestCase {
    @MainActor
    func testSelectedBoardsAreCopiedWithLinksMediaTranslationsAndLayouts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertTrue(source.addBoard("Family circle"))
        XCTAssertTrue(source.addBoard("Home places"))
        XCTAssertTrue(source.addBoard("Empty board"))
        XCTAssertTrue(source.addBoard("Hidden branch"))
        source.addItem(label: "Go home", symbol: "🏠", message: "Take me home",
                       category: "Family circle", imageData: nil,
                       destinationBoard: "Home places", linkBehavior: .navigate)
        source.addItem(label: "Kitchen", symbol: "🍽️", message: "I am in the kitchen",
                       category: "Home places", imageData: Data([1, 2, 3]),
                       spanishLabel: "Cocina", spanishMessage: "Estoy en la cocina")
        source.addItem(label: "Other branch", symbol: "➡️", message: "Other branch",
                       category: "Family circle", imageData: nil,
                       destinationBoard: "Hidden branch", linkBehavior: .navigate)
        source.setGridLayout(BoardGridLayout(columns: 2, rows: 3), for: "Family circle")
        source.setTileSize(.large, for: "Home places")
        let backup = try source.backupData()

        let targetURL = directory.appendingPathComponent("target.json")
        let target = CommunicationStore(storageURL: targetURL)
        XCTAssertTrue(target.addBoard("Family circle"))
        target.addItem(label: "Existing", symbol: "✅", message: "Keep me",
                       category: "Family circle", imageData: nil)
        target.settings.highContrast = true
        let previousID = target.items.first { $0.label == "Existing" }?.id
        let previousCount = target.items.count

        let imported = try target.addBoards(fromBackup: backup,
                                            selectedBoards: ["Family circle", "Home places", "Empty board"])
        XCTAssertEqual(imported, ["Family circle (imported 2)", "Home places", "Empty board"])
        XCTAssertEqual(target.items.count, previousCount + 3)
        XCTAssertEqual(target.items.first { $0.label == "Existing" }?.id, previousID)
        XCTAssertTrue(target.settings.highContrast)
        XCTAssertEqual(target.gridLayout(for: "Family circle (imported 2)"),
                       BoardGridLayout(columns: 2, rows: 3))
        XCTAssertEqual(target.tileSize(for: "Home places"), .large)

        let link = try XCTUnwrap(target.items.first { $0.category == "Family circle (imported 2)" })
        XCTAssertEqual(link.destinationBoard, "Home places")
        XCTAssertTrue(link.isCustom)
        let kitchen = try XCTUnwrap(target.items.first { $0.category == "Home places" })
        XCTAssertEqual(kitchen.imageData, Data([1, 2, 3]))
        XCTAssertEqual(target.translation(for: kitchen, language: "es")?.label, "Cocina")
        XCTAssertTrue(target.categories.contains("Empty board"))
        XCTAssertFalse(target.categories.contains("Hidden branch"))
        XCTAssertNil(target.items.first { $0.label == "Other branch" }?.destinationBoard)

        let reloaded = CommunicationStore(storageURL: targetURL)
        XCTAssertEqual(reloaded.items.first { $0.category == "Family circle (imported 2)" }?.destinationBoard,
                       "Home places")
        XCTAssertEqual(reloaded.items.first { $0.category == "Home places" }?.imageData, Data([1, 2, 3]))
        XCTAssertTrue(reloaded.settings.highContrast)
        let originalProfile = target.activeProfileID
        XCTAssertTrue(target.addProfile("Second"))
        XCTAssertFalse(target.categories.contains("Family circle (imported 2)"))
        XCTAssertTrue(target.switchProfile(to: originalProfile))
        XCTAssertTrue(target.categories.contains("Family circle (imported 2)"))
        XCTAssertEqual(try target.addBoards(fromBackup: backup, selectedBoards: ["Family circle"]),
                       ["Family circle (imported 3)"])
        let countBeforeInvalid = target.items.count
        XCTAssertThrowsError(try target.addBoards(fromBackup: backup, selectedBoards: ["Missing"]))
        XCTAssertEqual(target.items.count, countBeforeInvalid)
    }

    @MainActor
    func testStarterBoardCopyHasNewIdentityAndCanBeEdited() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let target = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        let originalIDs = Set(target.items.map(\.id))
        let imported = try target.addBoards(fromBackup: source.backupData(), selectedBoards: ["Core"])
        XCTAssertEqual(imported, ["Core (imported 2)"])
        let copied = target.items.filter { $0.category == "Core (imported 2)" }
        XCTAssertEqual(copied.count, source.items.filter { $0.category == "Core" }.count)
        XCTAssertTrue(copied.allSatisfy { $0.isCustom && !originalIDs.contains($0.id) })
    }
}
