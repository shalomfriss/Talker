import XCTest
@testable import OpenVoice

final class WebButtonTests: XCTestCase {
    func testWebAddressValidationAndOlderButtonDecoding() throws {
        XCTAssertEqual(ButtonWebLink.normalized("  example.com/help  "), "https://example.com/help")
        XCTAssertEqual(ButtonWebLink.normalized("https://www.youtube.com/watch?v=123"),
                       "https://www.youtube.com/watch?v=123")
        for address in ["", "https://", "http://example.com", "javascript:alert(1)",
                        "file:///private/test", "https://user:password@example.com",
                        String(repeating: "a", count: 2_001)] {
            XCTAssertNil(ButtonWebLink.normalized(address), address)
        }

        let item = CommunicationItem(label: "Website", symbol: "🌐", message: "Website", category: "Core")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        object.removeValue(forKey: "webURL")
        XCTAssertNil(try JSONDecoder().decode(CommunicationItem.self,
            from: JSONSerialization.data(withJSONObject: object)).webURL)
    }

    @MainActor
    func testWebButtonKeepsMessageAndSurvivesProfileBackupAndBoardTransfer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("web-buttons.json")
        let store = CommunicationStore(storageURL: file)
        let initialCount = store.items.count
        store.addItem(label: "Broken", symbol: "🌐", message: "", category: "Core",
                      imageData: nil, webURL: "javascript:alert(1)", action: .openWebPage)
        XCTAssertEqual(store.items.count, initialCount)

        store.addItem(label: "My website", symbol: "🌐", message: "", category: "Core",
                      imageData: nil, webURL: "example.com/help", action: .openWebPage)
        let item = try XCTUnwrap(store.items.last)
        XCTAssertEqual(item.effectiveAction, .openWebPage)
        XCTAssertEqual(item.webURL, "https://example.com/help")
        let draft = store.composedMessage
        store.select(item)
        XCTAssertEqual(store.composedMessage, draft)

        var invalidEdit = item
        invalidEdit.webURL = "file:///private/test"
        store.updateItem(invalidEdit)
        XCTAssertEqual(store.items.last?.webURL, item.webURL)

        let boardData = try OpenBoardFormat.exportBoard(name: "Core", items: [item], language: "en")
        let imported = try OpenBoardFormat.importData(boardData, fileExtension: "obf")
        XCTAssertEqual(imported.items.first?.effectiveAction, .openWebPage)
        XCTAssertEqual(imported.items.first?.webURL, item.webURL)
        XCTAssertThrowsError(try QRPageTransfer.encode(title: "Core", icon: nil, items: [item],
                                                    translations: [:]))

        XCTAssertEqual(CommunicationStore(storageURL: file).items.last?.webURL, item.webURL)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.last?.webURL, item.webURL)
        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertFalse(store.items.contains(where: { $0.webURL != nil }))
        XCTAssertTrue(store.switchProfile(to: profileID))
        XCTAssertEqual(store.items.last?.webURL, item.webURL)
    }
}
