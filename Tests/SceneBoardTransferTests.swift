import XCTest
@testable import OpenVoice

final class SceneBoardTransferTests: XCTestCase {
    func testOlderSingleSceneFileWithoutLinkedScenesStillImports() throws {
        let scene = VisualSceneBoard(title: "Kitchen", imageData: Data([1]),
                                     hotspots: [SceneHotspot(option: ChoiceOption(label: "Door"),
                                                             x: 0.5, y: 0.5)])
        let data = try SceneBoardTransfer.exportData(scene, using: [])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "linkedScenes")
        let olderData = try JSONSerialization.data(withJSONObject: json)
        let imported = try SceneBoardTransfer.importBundle(olderData)
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].title, "Kitchen")
        XCTAssertNil(imported[0].hotspots[0].destinationSceneID)
    }

    @MainActor
    func testLinkedSceneFileIncludesRelatedScenesAndRemapsBothDirections() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        var home = VisualSceneBoard(title: "Home", imageData: Data([1]), hotspots: [])
        let garden = VisualSceneBoard(title: "Garden", imageData: Data([2]),
                                      hotspots: [SceneHotspot(option: ChoiceOption(label: "home"),
                                                              x: 0.4, y: 0.6,
                                                              destinationSceneID: home.id)])
        home.hotspots = [SceneHotspot(option: ChoiceOption(label: "garden"), x: 0.2, y: 0.3,
                                      destinationSceneID: garden.id)]
        XCTAssertTrue(source.saveSceneBoard(garden))
        XCTAssertTrue(source.saveSceneBoard(home))
        let data = try SceneBoardTransfer.exportData(home, using: source.items,
                                                     allBoards: source.sceneBoards)
        let decoded = try JSONDecoder().decode(SceneBoardTransfer.self, from: data)
        XCTAssertEqual(decoded.linkedScenes?.count, 1)

        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let importedHome = try recipient.importSceneBoard(data)
        let importedGarden = try XCTUnwrap(recipient.sceneBoards.first(where: { $0.title == "Garden" }))
        XCTAssertNotEqual(importedHome.id, home.id)
        XCTAssertNotEqual(importedGarden.id, garden.id)
        XCTAssertEqual(importedHome.hotspots[0].destinationSceneID, importedGarden.id)
        XCTAssertEqual(importedGarden.hotspots[0].destinationSceneID, importedHome.id)
        XCTAssertEqual(recipient.sceneBoards.count, 2)
        XCTAssertEqual(try recipient.importSceneBoard(data).title, "Home (imported 2)")
        XCTAssertEqual(recipient.sceneBoards.count, 4)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(recipient.backupData())
        XCTAssertEqual(restored.sceneBoards.first(where: { $0.id == importedHome.id })?.hotspots[0]
            .destinationSceneID, importedGarden.id)
    }

    @MainActor
    func testSceneFileKeepsPhotoAndWordMediaAcrossProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let photo = Data([1, 2, 3, 4])
        let wordPhoto = Data([5, 6, 7])
        let voice = Data([8, 9, 10])
        source.addItem(label: "books", symbol: "📚", message: "I want my books", category: "Things",
                       imageData: wordPhoto, audioData: voice)
        let word = try XCTUnwrap(source.items.first { $0.label == "books" && $0.isCustom })
        let scene = VisualSceneBoard(title: "Library", imageData: photo,
                                     hotspots: [SceneHotspot(option: ChoiceOption(item: word), x: 0.25, y: 0.75)])
        XCTAssertTrue(source.saveSceneBoard(scene))
        let exported = try SceneBoardTransfer.exportData(scene, using: source.items)

        let recipientFile = directory.appendingPathComponent("recipient.json")
        let recipient = CommunicationStore(storageURL: recipientFile)
        let imported = try recipient.importSceneBoard(exported)
        XCTAssertNotEqual(imported.id, scene.id)
        XCTAssertNotEqual(imported.hotspots[0].id, scene.hotspots[0].id)
        XCTAssertNotEqual(imported.hotspots[0].option.id, word.id)
        XCTAssertEqual(imported.imageData, photo)
        XCTAssertEqual(imported.hotspots[0].x, 0.25)
        XCTAssertEqual(imported.hotspots[0].y, 0.75)
        XCTAssertEqual(imported.hotspots[0].option.message, "I want my books")
        XCTAssertEqual(imported.hotspots[0].option.imageData, wordPhoto)
        XCTAssertEqual(imported.hotspots[0].option.audioData, voice)
        XCTAssertEqual(try recipient.importSceneBoard(exported).title, "Library (imported 2)")
        XCTAssertEqual(CommunicationStore(storageURL: recipientFile).sceneBoards.first, imported)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(recipient.backupData())
        XCTAssertEqual(restored.sceneBoards.first, imported)
    }

    func testSceneFileRejectsWrongFormatAndInvalidScene() throws {
        XCTAssertThrowsError(try SceneBoardTransfer.importBoard(Data("{\"hello\":true}".utf8))) { error in
            XCTAssertEqual(error as? SceneBoardTransferError, .unsupportedFormat)
        }
        let invalid = VisualSceneBoard(title: "Kitchen", imageData: Data([1]),
                                       hotspots: [SceneHotspot(option: ChoiceOption(label: "Door"),
                                                               x: 1.1, y: 0.5)])
        let exported = try SceneBoardTransfer.exportData(invalid, using: [])
        XCTAssertThrowsError(try SceneBoardTransfer.importBoard(exported)) { error in
            XCTAssertEqual(error as? SceneBoardTransferError, .invalidScene)
        }
    }
}
