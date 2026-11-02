import XCTest
import UIKit
@testable import OpenVoice

final class RoutineStepTimerTests: XCTestCase {
    func testClockUsesRealElapsedTimeAcrossPauseAndResume() {
        let start = Date(timeIntervalSince1970: 1_000)
        var clock = RoutineStepClock(durationSeconds: 180)
        XCTAssertEqual(clock.secondsRemaining(at: start), 180)
        clock.start(at: start)
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(30)), 150)
        clock.pause(at: start.addingTimeInterval(45))
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(1_000)), 135)
        clock.resume(at: start.addingTimeInterval(1_000))
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(1_120)), 15)
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(1_200)), 0)
        clock.finish()
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(1_200)), 0)
        clock.reset()
        XCTAssertEqual(clock.secondsRemaining(at: start.addingTimeInterval(1_200)), 180)
    }

    func testOlderRoutineStepDecodesWithoutTimer() throws {
        let data = Data("{\"id\":\"\(UUID().uuidString)\",\"title\":\"Brush teeth\",\"symbol\":\"🪥\",\"isComplete\":false}".utf8)
        let step = try JSONDecoder().decode(RoutineStep.self, from: data)
        XCTAssertNil(step.durationSeconds)
        XCTAssertNil(step.imageData)
        XCTAssertNil(step.audioData)
        XCTAssertNil(step.spokenText)
        XCTAssertNil(step.videoData)
        XCTAssertNil(step.videoPosterData)
        XCTAssertNil(step.choiceBoardID)
        XCTAssertEqual(step.spokenMessage, "Brush teeth")
        XCTAssertEqual(step.title, "Brush teeth")
    }

    @MainActor
    func testRoutineVideoPersistsAcrossTemplateProfileAndBackup() async throws {
        let clipURL = try XCTUnwrap(Bundle.main.url(forResource: "SceneSample", withExtension: "mov"))
        let prepared = try await SceneVideoProcessing.prepared(
            from: clipURL, byteLimit: SceneVideoProcessing.maxHotspotBytes)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("routine-video.json")
        let store = CommunicationStore(storageURL: file)
        var step = RoutineStep(title: "Watch the bus", symbol: "🚌",
                               videoData: prepared.video, videoPosterData: prepared.poster)
        XCTAssertTrue(step.hasValidVideoMedia)
        XCTAssertEqual(step.displayImageData, prepared.poster)
        XCTAssertTrue(store.saveRoutineStep(step))
        step.title = "Watch the school bus"
        XCTAssertTrue(store.saveRoutineStep(step))
        XCTAssertEqual(CommunicationStore(storageURL: file).routines.last?.videoData, prepared.video)
        XCTAssertTrue(store.saveRoutineTemplate(name: "Bus trip"))
        let template = try XCTUnwrap(store.routineTemplates.first)
        XCTAssertEqual(template.steps.last?.videoPosterData, prepared.poster)
        XCTAssertTrue(store.loadRoutineTemplate(id: template.id))
        XCTAssertEqual(store.routines.last?.videoData, prepared.video)
        let profileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other traveler"))
        XCTAssertFalse(store.routines.contains { $0.videoData != nil })
        XCTAssertTrue(store.switchProfile(to: profileID))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.routines.last?.videoData, prepared.video)
        XCTAssertEqual(restored.routineTemplates.first?.steps.last?.videoPosterData, prepared.poster)
    }

    @MainActor
    func testRoutineStepRejectsVideoWithoutPosterOrOversizedClip() {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let incomplete = RoutineStep(title: "Invalid clip", symbol: "▶️", videoData: Data([1]))
        XCTAssertFalse(store.saveRoutineStep(incomplete))
        let oversized = RoutineStep(title: "Oversized clip", symbol: "▶️",
            videoData: Data(count: SceneVideoProcessing.maxHotspotBytes + 1),
            videoPosterData: Data([1]))
        XCTAssertFalse(store.saveRoutineStep(oversized))
        XCTAssertFalse(store.routines.contains { $0.title == "Invalid clip" || $0.title == "Oversized clip" })
    }

    @MainActor
    func testRoutinePhotoAndVoicePersistAcrossEditingProfilesAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let imageData = try XCTUnwrap(PhotoProcessing.preparedData(from: try XCTUnwrap(photo.pngData())))
        let audioData = try XCTUnwrap(ScanCueSound.wavData(for: .blip))
        var step = RoutineStep(title: "Pack bag", symbol: "🎒", durationSeconds: 300,
                               imageData: imageData, audioData: audioData,
                               spokenText: "Put your bag by the door")
        XCTAssertTrue(source.saveRoutineStep(step))
        XCTAssertEqual(source.routines.last?.spokenMessage, "Put your bag by the door")
        XCTAssertEqual(source.routines.last?.imageData, imageData)
        XCTAssertEqual(source.routines.last?.audioData, audioData)
        source.toggleRoutineStep(step)
        step.title = "Pack school bag"
        XCTAssertTrue(source.saveRoutineStep(step))
        XCTAssertEqual(source.routines.last?.title, "Pack school bag")
        XCTAssertTrue(source.routines.last?.isComplete == true)

        let reopened = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        XCTAssertEqual(reopened.routines.last?.imageData, imageData)
        XCTAssertEqual(reopened.routines.last?.audioData, audioData)
        XCTAssertEqual(reopened.routines.last?.spokenMessage, "Put your bag by the door")
        let firstProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Another person"))
        XCTAssertFalse(source.routines.contains { $0.id == step.id })
        XCTAssertTrue(source.switchProfile(to: firstProfile))

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.routines.last?.imageData, imageData)
        XCTAssertEqual(restored.routines.last?.audioData, audioData)
        XCTAssertEqual(restored.routines.last?.spokenMessage, "Put your bag by the door")
        XCTAssertTrue(restored.routines.last?.isComplete == true)
    }

    @MainActor
    func testStepTimerPersistsWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        source.addRoutineStep("Quiet reading", symbol: "📖", durationSeconds: 300)
        let step = try XCTUnwrap(source.routines.last)
        XCTAssertEqual(step.durationSeconds, 300)
        source.setRoutineStepDuration(stepID: step.id, durationSeconds: 600)
        XCTAssertEqual(source.routines.last?.durationSeconds, 600)
        source.setRoutineStepDuration(stepID: step.id, durationSeconds: -5)
        XCTAssertEqual(source.routines.last?.durationSeconds, 600)
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
            .routines.last?.durationSeconds, 600)

        let originalProfile = source.activeProfileID
        XCTAssertTrue(source.addProfile("Another routine"))
        XCTAssertFalse(source.routines.contains { $0.id == step.id })
        XCTAssertTrue(source.switchProfile(to: originalProfile))
        XCTAssertEqual(source.routines.last?.durationSeconds, 600)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(source.backupData())
        XCTAssertEqual(restored.routines.last?.durationSeconds, 600)

        source.setRoutineStepDuration(stepID: step.id, durationSeconds: nil)
        XCTAssertNil(source.routines.last?.durationSeconds)
    }
}
