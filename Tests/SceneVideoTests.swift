import AVFoundation
import UIKit
import XCTest
@testable import OpenVoice

final class SceneVideoTests: XCTestCase {
    @MainActor
    func testPreparedVideoSurvivesStorageBackupAndSceneFile() async throws {
        let sourceURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let prepared = try await SceneVideoProcessing.prepared(from: sourceURL)
        XCTAssertFalse(prepared.video.isEmpty)
        XCTAssertLessThanOrEqual(prepared.video.count, SceneVideoProcessing.maxStoredBytes)
        XCTAssertNotNil(UIImage(data: prepared.poster))

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let scene = VisualSceneBoard(title: "Playground video", imageData: prepared.poster,
            hotspots: [SceneHotspot(option: ChoiceOption(label: "slide"), x: 0.5, y: 0.5)],
            videoData: prepared.video)
        XCTAssertTrue(store.saveSceneBoard(scene))
        XCTAssertEqual(CommunicationStore(storageURL: file).sceneBoards.first, scene)

        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let imported = try recipient.importSceneBoard(SceneBoardTransfer.exportData(scene, using: []))
        XCTAssertEqual(imported.videoData, prepared.video)
        XCTAssertEqual(imported.imageData, prepared.poster)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.sceneBoards.first, scene)
    }

    @MainActor
    func testInvalidVideoPayloadCannotBeSavedOrImported() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("data.json"))
        let scene = VisualSceneBoard(title: "Broken video", imageData: Data([1]),
            hotspots: [SceneHotspot(option: ChoiceOption(label: "go"), x: 0.5, y: 0.5)],
            videoData: Data())
        XCTAssertFalse(store.saveSceneBoard(scene))
        XCTAssertThrowsError(try SceneBoardTransfer.importBoard(
            SceneBoardTransfer.exportData(scene, using: [])))
    }

    @MainActor
    func testHotspotVideoSurvivesBackupAndSceneFile() async throws {
        let sourceURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let prepared = try await SceneVideoProcessing.prepared(
            from: sourceURL, byteLimit: SceneVideoProcessing.maxHotspotBytes)
        let hotspot = SceneHotspot(option: ChoiceOption(label: "Watch slide"), x: 0.5, y: 0.5,
                                   videoData: prepared.video, videoPosterData: prepared.poster)
        XCTAssertTrue(hotspot.hasValidMedia)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let scene = VisualSceneBoard(title: "Playground", imageData: Data([1]), hotspots: [hotspot])
        XCTAssertTrue(store.saveSceneBoard(scene))
        XCTAssertEqual(CommunicationStore(storageURL: file).sceneBoards.first, scene)

        let recipient = CommunicationStore(storageURL: directory.appendingPathComponent("recipient.json"))
        let imported = try recipient.importSceneBoard(SceneBoardTransfer.exportData(scene, using: []))
        XCTAssertEqual(imported.hotspots.first?.videoData, prepared.video)
        XCTAssertEqual(imported.hotspots.first?.videoPosterData, prepared.poster)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.sceneBoards.first, scene)
    }

    @MainActor
    func testHotspotVideoRequiresPosterAndCannotAlsoOpenScene() throws {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let clip = Data([1, 2, 3])
        let noPoster = SceneHotspot(option: ChoiceOption(label: "Watch"), x: 0.5, y: 0.5,
                                    videoData: clip)
        let mixedAction = SceneHotspot(option: ChoiceOption(label: "Watch"), x: 0.5, y: 0.5,
                                       destinationSceneID: UUID(), videoData: clip,
                                       videoPosterData: Data([4]))
        for hotspot in [noPoster, mixedAction] {
            XCTAssertFalse(hotspot.hasValidMedia)
            let scene = VisualSceneBoard(title: UUID().uuidString, imageData: Data([1]),
                                         hotspots: [hotspot])
            XCTAssertFalse(store.saveSceneBoard(scene))
            XCTAssertThrowsError(try SceneBoardTransfer.importBoard(
                SceneBoardTransfer.exportData(scene, using: [])))
        }
    }

    func testSceneMediaBudgetKeepsMultipleVideoClipsBounded() {
        let clip = Data(repeating: 0, count: SceneVideoProcessing.maxHotspotBytes)
        let words = (0..<3).map { index in
            SceneHotspot(option: ChoiceOption(label: "Clip \(index)"), x: 0.5, y: 0.5,
                         videoData: clip, videoPosterData: Data([1]))
        }
        let scene = VisualSceneBoard(title: "Clips", imageData: Data([1]), hotspots: words)
        XCTAssertFalse(scene.hasValidMedia)
        XCTAssertTrue(VisualSceneBoard(title: "Photos", imageData: Data(count: 1),
                                       hotspots: [SceneHotspot(option: ChoiceOption(label: "Go"),
                                                               x: 0.5, y: 0.5)]).hasValidMedia)
    }
}
