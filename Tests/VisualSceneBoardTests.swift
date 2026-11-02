import XCTest
@testable import OpenVoice

final class VisualSceneBoardTests: XCTestCase {
    func testHotspotPositionClampsAndRejectsNonFiniteValues() {
        let hotspot = SceneHotspot(option: ChoiceOption(label: "Door"), x: 0.5, y: 0.5)
        XCTAssertTrue(hotspot.hasValidPosition)
        XCTAssertEqual(hotspot.moved(toX: -2, y: 3).x, 0)
        XCTAssertEqual(hotspot.moved(toX: -2, y: 3).y, 1)
        XCTAssertEqual(hotspot.moved(toX: .infinity, y: .nan).x, 0.5)
        XCTAssertFalse(SceneHotspot(option: hotspot.option, x: -0.1, y: 0.5).hasValidPosition)
        let wide = SceneHotspot(option: hotspot.option, x: 0.5, y: 0.5,
                                width: 0.6, height: 0.4)
        XCTAssertEqual(wide.moved(toX: 1, y: 0).x, 0.7, accuracy: 0.0001)
        XCTAssertEqual(wide.moved(toX: 1, y: 0).y, 0.2, accuracy: 0.0001)
    }

    func testOlderHotspotWithoutDestinationStillSpeaks() throws {
        let hotspot = SceneHotspot(option: ChoiceOption(label: "Door"), x: 0.5, y: 0.5)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(hotspot)) as? [String: Any])
        json.removeValue(forKey: "destinationSceneID")
        let decoded = try JSONDecoder().decode(SceneHotspot.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.destinationSceneID)
        XCTAssertEqual(decoded.option.label, "Door")
        XCTAssertNil(decoded.width)
        XCTAssertNil(decoded.height)
        XCTAssertNil(decoded.backgroundColorHex)
        XCTAssertNil(decoded.showsLabel)
        XCTAssertEqual(decoded.effectiveBehavior, .speakAndAdd)
        XCTAssertNil(decoded.spokenText)
        XCTAssertNil(decoded.videoData)
        XCTAssertNil(decoded.videoPosterData)
    }

    @MainActor
    func testCustomizedHotspotsValidateAndSurviveSceneFileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let customized = SceneHotspot(option: ChoiceOption(label: "Book"), x: 0.3, y: 0.4,
                                      width: 0.36, height: 0.18, backgroundColorHex: "#315A78",
                                      showsLabel: false, behavior: .addOnly,
                                      spokenText: "Read a book")
        let scene = VisualSceneBoard(title: "Reading", imageData: Data([1]), hotspots: [customized])
        XCTAssertTrue(source.saveSceneBoard(scene))
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .sceneBoards.first?.hotspots.first, customized)

        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let imported = try recipient.importSceneBoard(SceneBoardTransfer.exportData(scene, using: []))
        XCTAssertEqual(imported.hotspots.first?.width, 0.36)
        XCTAssertEqual(imported.hotspots.first?.height, 0.18)
        XCTAssertEqual(imported.hotspots.first?.backgroundColorHex, "#315A78")
        XCTAssertEqual(imported.hotspots.first?.showsLabel, false)
        XCTAssertEqual(imported.hotspots.first?.effectiveBehavior, .addOnly)
        XCTAssertEqual(imported.hotspots.first?.spokenText, "Read a book")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.sceneBoards.first?.hotspots.first, customized)

        for invalid in [
            SceneHotspot(option: customized.option, x: 0.3, y: 0.4, width: .infinity),
            SceneHotspot(option: customized.option, x: 0.3, y: 0.4, height: 0.9),
            SceneHotspot(option: customized.option, x: 0.3, y: 0.4, backgroundColorHex: "invalid"),
            SceneHotspot(option: customized.option, x: 0.3, y: 0.4, spokenText: "  ")
        ] {
            XCTAssertFalse(source.saveSceneBoard(VisualSceneBoard(title: UUID().uuidString,
                imageData: Data([1]), hotspots: [invalid])))
        }
    }

    @MainActor
    func testCustomSceneTextOverridesVocabularyTranslation() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = CommunicationStore(storageURL: file)
        let word = try XCTUnwrap(store.items.first { $0.label == "yes" })
        store.settings.communicationLanguage = "es"
        XCTAssertNotEqual(store.displayMessage(for: word), "I would like that")
        store.select(word, speakFeedback: false, messageOverride: "I would like that")
        XCTAssertEqual(store.composedMessage, "I would like that")
    }

    @MainActor
    func testDeletingSceneTurnsItsIncomingLinksIntoSpeakingWords() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = CommunicationStore(storageURL: file)
        let destination = VisualSceneBoard(title: "Garden", imageData: Data([1]),
                                           hotspots: [SceneHotspot(option: ChoiceOption(label: "flowers"), x: 0.5, y: 0.5)])
        let source = VisualSceneBoard(title: "Home", imageData: Data([2]),
                                      hotspots: [SceneHotspot(option: ChoiceOption(label: "garden"),
                                                              x: 0.5, y: 0.5,
                                                              destinationSceneID: destination.id)])
        XCTAssertTrue(store.saveSceneBoard(destination))
        XCTAssertTrue(store.saveSceneBoard(source))
        store.deleteSceneBoard(id: destination.id)
        XCTAssertNil(store.sceneBoards.first?.hotspots.first?.destinationSceneID)
        XCTAssertEqual(CommunicationStore(storageURL: file).sceneBoards.first?.hotspots.first?.option.label,
                       "garden")
    }

    @MainActor
    func testSceneLabelModeDefaultsAndStaysWithProfileAndBackup() throws {
        let older = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(older.sceneLabelMode, .always)
        let unknown = try JSONDecoder().decode(AppSettings.self,
                                               from: Data("{\"sceneLabelMode\":\"unknown\"}".utf8))
        XCTAssertEqual(unknown.sceneLabelMode, .always)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        store.settings.sceneLabelMode = .onTap
        XCTAssertEqual(CommunicationStore(storageURL: file).settings.sceneLabelMode, .onTap)
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertEqual(store.settings.sceneLabelMode, .always)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.settings.sceneLabelMode, .onTap)

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.settings.sceneLabelMode, .onTap)
    }

    @MainActor
    func testSceneStaysWithProfileAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        let option = ChoiceOption(item: try XCTUnwrap(store.items.first(where: { $0.label == "yes" })))
        let scene = VisualSceneBoard(title: "Kitchen", imageData: Data([1, 2, 3]),
                                     hotspots: [SceneHotspot(option: option, x: 0.25, y: 0.75)])
        XCTAssertTrue(store.saveSceneBoard(scene))
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.sceneBoards.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.sceneBoards, [scene])
        XCTAssertEqual(CommunicationStore(storageURL: file).sceneBoards, [scene])

        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.sceneBoards, [scene])
        imported.deleteSceneBoard(id: scene.id)
        XCTAssertTrue(imported.sceneBoards.isEmpty)
    }

    @MainActor
    func testSceneValidationAndDeletedWordCopy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        let word = try XCTUnwrap(store.items.first(where: { $0.label == "yes" }))
        let option = ChoiceOption(item: word)
        let hotspot = SceneHotspot(option: option, x: 0.5, y: 0.5)
        let scene = VisualSceneBoard(title: "  My room  ", imageData: Data([1]), hotspots: [hotspot])
        XCTAssertTrue(store.saveSceneBoard(scene))
        XCTAssertEqual(store.sceneBoards[0].title, "My room")
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "my ROOM", imageData: Data([1]), hotspots: [hotspot])))
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "No words", imageData: Data([1]), hotspots: [])))
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "No photo", imageData: Data(), hotspots: [hotspot])))
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "Bad position", imageData: Data([1]),
                                                        hotspots: [SceneHotspot(option: option, x: 1.1, y: 0.5)])))
        XCTAssertFalse(store.saveSceneBoard(VisualSceneBoard(title: "Too many", imageData: Data([1]),
                                                        hotspots: (0..<13).map { _ in SceneHotspot(option: option, x: 0.5, y: 0.5) })))
        store.deleteItem(word)
        XCTAssertEqual(hotspot.option.resolved(using: store.items).label, "yes")
        XCTAssertEqual(hotspot.option.resolved(using: store.items).message, word.message)
    }

    @MainActor
    func testPictureButtonSceneAndKeyboardLinksPersistAndUseSafeTransfers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("scene-tiles.json")
        let store = CommunicationStore(storageURL: file)
        let scene = VisualSceneBoard(title: "Garden", imageData: Data([1]),
                                     hotspots: [SceneHotspot(option: ChoiceOption(label: "flower"),
                                                             x: 0.5, y: 0.5)])
        XCTAssertTrue(store.saveSceneBoard(scene))
        let before = store.items.count
        store.addItem(label: "Broken scene", symbol: "🖼️", message: "Broken scene",
                      category: "Core", imageData: nil, destinationSceneID: UUID(), action: .openScene)
        XCTAssertEqual(store.items.count, before)
        store.addItem(label: "Garden scene", symbol: "🖼️", message: "Garden scene",
                      category: "Core", imageData: nil, destinationSceneID: scene.id, action: .openScene)
        store.addItem(label: "Keyboard", symbol: "⌨️", message: "Keyboard",
                      category: "Core", imageData: nil, action: .openKeyboard)
        let sceneTile = try XCTUnwrap(store.items.first { $0.label == "Garden scene" })
        let keyboardTile = try XCTUnwrap(store.items.first { $0.label == "Keyboard" })
        XCTAssertEqual(sceneTile.effectiveAction, .openScene)
        XCTAssertEqual(keyboardTile.effectiveAction, .openKeyboard)
        store.select(sceneTile)
        store.select(keyboardTile)
        XCTAssertTrue(store.messageParts.isEmpty)

        let boardData = try OpenBoardFormat.exportBoard(name: "Core",
            items: [sceneTile, keyboardTile], language: "en")
        let imported = try OpenBoardFormat.importData(boardData, fileExtension: "obf")
        XCTAssertEqual(imported.items.first?.effectiveAction, .addToMessage)
        XCTAssertEqual(imported.items.last?.effectiveAction, .openKeyboard)
        XCTAssertThrowsError(try QRPageTransfer.encode(title: "Core", icon: nil,
            items: [sceneTile], translations: [:]))
        let keyboardCode = try QRPageTransfer.encode(title: "Core", icon: nil,
            items: [keyboardTile], translations: [:])
        XCTAssertEqual(try QRPageTransfer.decode(keyboardCode).tiles.first?.action, .openKeyboard)

        XCTAssertEqual(CommunicationStore(storageURL: file).items.first {
            $0.label == "Garden scene"
        }?.destinationSceneID, scene.id)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.items.first { $0.label == "Garden scene" }?.destinationSceneID,
                       scene.id)
        store.deleteSceneBoard(id: scene.id)
        let unlinked = try XCTUnwrap(store.items.first { $0.label == "Garden scene" })
        XCTAssertNil(unlinked.destinationSceneID)
        XCTAssertEqual(unlinked.effectiveAction, .addToMessage)
        store.select(unlinked)
        XCTAssertEqual(store.messageParts.last, "Garden scene")
    }
}
