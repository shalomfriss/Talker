import XCTest
@testable import OpenVoice

final class BoardOnlyModeTests: XCTestCase {
    func testPINValidationAndDeviceKeychainStorage() throws {
        let profileID = UUID()
        defer { BoardOnlyPINStore.delete(for: profileID) }
        XCTAssertFalse(BoardOnlyPINStore.isValid("123"))
        XCTAssertFalse(BoardOnlyPINStore.isValid("123456789"))
        XCTAssertFalse(BoardOnlyPINStore.isValid("12a4"))
        XCTAssertTrue(BoardOnlyPINStore.isValid("123456"))
        try BoardOnlyPINStore.save("123456", for: profileID)
        XCTAssertTrue(BoardOnlyPINStore.hasPIN(for: profileID))
        XCTAssertFalse(BoardOnlyPINStore.matches("654321", for: profileID))
        XCTAssertTrue(BoardOnlyPINStore.matches("123456", for: profileID))
        try BoardOnlyPINStore.save("4829", for: profileID)
        XCTAssertFalse(BoardOnlyPINStore.matches("123456", for: profileID))
        XCTAssertTrue(BoardOnlyPINStore.matches("4829", for: profileID))
    }

    @MainActor
    func testBoardOnlyModePersistsAndBlocksBoardChangesUntilPINExit() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("board-only.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        defer { BoardOnlyPINStore.delete(for: firstID) }
        XCTAssertTrue(store.addProfile("Second person"))
        let secondID = store.activeProfileID
        XCTAssertTrue(store.switchProfile(to: firstID))
        let choice = ChoiceBoard(title: "Drink", options: [ChoiceOption(label: "Water"), ChoiceOption(label: "Juice")])
        XCTAssertTrue(store.saveChoiceBoard(choice))
        let word = try XCTUnwrap(store.items.first { $0.label == "yes" })
        let scene = VisualSceneBoard(title: "Kitchen", imageData: Data([1]),
                                     hotspots: [SceneHotspot(option: ChoiceOption(item: word), x: 0.5, y: 0.5)])
        XCTAssertTrue(store.saveSceneBoard(scene))
        let choiceBoardCount = store.choiceBoards.count
        let sceneBoardCount = store.sceneBoards.count

        try store.startBoardOnlyMode(pin: "4829")
        XCTAssertTrue(store.isBoardOnlyModeActive)
        XCTAssertFalse(store.switchProfile(to: secondID))
        XCTAssertFalse(store.addProfile("Third person"))
        XCTAssertFalse(store.saveChoiceBoard(ChoiceBoard(title: "Food", options: choice.options)))
        store.deleteChoiceBoard(id: choice.id)
        XCTAssertEqual(store.choiceBoards.count, choiceBoardCount)
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "Garden", imageData: scene.imageData,
                                                            hotspots: scene.hotspots)))
        store.deleteSceneBoard(id: scene.id)
        XCTAssertEqual(store.sceneBoards.count, sceneBoardCount)
        XCTAssertFalse(store.leaveBoardOnlyMode(pin: "0000"))
        XCTAssertTrue(store.isBoardOnlyModeActive)

        let reloaded = CommunicationStore(storageURL: file)
        XCTAssertTrue(reloaded.isBoardOnlyModeActive)
        let backup = try store.backupData()
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(backup)
        XCTAssertFalse(imported.isBoardOnlyModeActive)
        XCTAssertFalse(imported.settings.boardOnlyModeActive)
        XCTAssertFalse(BoardOnlyPINStore.hasPIN(for: imported.activeProfileID))

        XCTAssertTrue(store.leaveBoardOnlyMode(pin: "4829"))
        XCTAssertFalse(store.isBoardOnlyModeActive)
        XCTAssertTrue(store.switchProfile(to: secondID))
        XCTAssertFalse(store.isBoardOnlyModeActive)
        store.settings.boardOnlyModeActive = true
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertTrue(store.switchProfile(to: secondID))
        XCTAssertFalse(store.settings.boardOnlyModeActive)
        XCTAssertFalse(CommunicationStore(storageURL: file).settings.boardOnlyModeActive)
    }
}
