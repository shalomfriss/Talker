import XCTest
@testable import OpenVoice

final class LocalBackupTests: XCTestCase {
    @MainActor
    func testNamedSnapshotSupportsSelectedAndFullRestoreWithoutBeingReplaced() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.addBoard("Saved board"))
        store.addItem(label: "Saved word", symbol: "💬", message: "Saved message",
                      category: "Saved board", imageData: nil)
        let snapshot = try store.createLocalBackup(named: "  Before changes  ")
        XCTAssertEqual(snapshot.name, "Before changes")
        XCTAssertEqual(try store.localBackups().map(\.id), [snapshot.id])
        XCTAssertTrue(store.addBoard("Later board"))
        let restoredBoards = try store.addBoards(fromBackup: store.localBackupData(id: snapshot.id),
                                                 selectedBoards: ["Saved board"])
        XCTAssertEqual(restoredBoards, ["Saved board (imported 2)"])
        XCTAssertTrue(store.categories.contains("Later board"))
        XCTAssertTrue(store.items.contains { $0.category == "Saved board (imported 2)" && $0.label == "Saved word" })

        try store.importBackup(store.localBackupData(id: snapshot.id))
        XCTAssertFalse(store.categories.contains("Later board"))
        XCTAssertFalse(store.categories.contains("Saved board (imported 2)"))
        XCTAssertEqual(try store.localBackups().map(\.id), [snapshot.id])
        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(try relaunched.localBackups().map(\.id), [snapshot.id])
        XCTAssertEqual(relaunched.items.first { $0.category == "Saved board" }?.message, "Saved message")

        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.addProfile("Another voice"))
        XCTAssertTrue(try store.localBackups().isEmpty)
        let secondSnapshot = try store.createLocalBackup(named: "Second profile")
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(try store.localBackups().map(\.id), [snapshot.id])
        try store.deleteLocalBackup(id: snapshot.id)
        XCTAssertTrue(try store.localBackups().isEmpty)
        XCTAssertThrowsError(try store.localBackupData(id: snapshot.id))
        XCTAssertTrue(store.switchProfile(to: secondSnapshot.profileID))
        XCTAssertEqual(try store.localBackups().map(\.id), [secondSnapshot.id])
    }

    @MainActor
    func testInvalidNameAndCorruptSnapshotCannotBeRestored() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("profile.json"))
        XCTAssertThrowsError(try store.createLocalBackup(named: "   "))
        XCTAssertTrue(try store.localBackups().isEmpty)
        let snapshot = try store.createLocalBackup(named: "Good backup")
        let backupFile = directory.appendingPathComponent("local-backups")
            .appendingPathComponent(store.activeProfileID.uuidString)
            .appendingPathComponent(snapshot.id.uuidString)
            .appendingPathComponent("backup.json")
        try Data("broken".utf8).write(to: backupFile, options: .atomic)
        XCTAssertThrowsError(try store.localBackupData(id: snapshot.id))
        let raw = try await store.localBackupDataAsync(id: snapshot.id)
        do {
            _ = try await PendingBackupImport.prepare(data: raw)
            XCTFail("The preview must reject a corrupt local backup")
        } catch is DecodingError {
            // The preview validates the raw snapshot before showing restore controls.
        }
    }
}
