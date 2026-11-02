import XCTest
@testable import OpenVoice

final class FocusWordsTests: XCTestCase {
    func testFocusTargetsEncodeAndOldSettingsDefaultToNone() throws {
        let oldData = Data("{\"speechRate\":0.48}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(AppSettings.self, from: oldData).focusWordIDs.isEmpty)

        var settings = AppSettings()
        let id = UUID()
        settings.focusWordIDs = [id]
        let restored = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.focusWordIDs, [id])
    }

    @MainActor
    func testFocusTargetsStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstProfile = source.activeProfileID
        let target = try XCTUnwrap(source.items.first(where: { $0.label == "want" }))
        source.settings.focusWordIDs = [target.id]

        XCTAssertTrue(source.addProfile("Second"))
        XCTAssertTrue(source.settings.focusWordIDs.isEmpty)
        XCTAssertTrue(source.switchProfile(to: firstProfile))
        XCTAssertEqual(source.settings.focusWordIDs, [target.id])
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .settings.focusWordIDs, [target.id])

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("target.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.settings.focusWordIDs, [target.id])
    }
}
