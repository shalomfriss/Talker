import XCTest
@testable import OpenVoice

final class RoutineHistoryTests: XCTestCase {
    @MainActor
    func testRecordsKeepStepSnapshotAndStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("routine-history.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        store.resetRoutine()
        XCTAssertFalse(store.recordRoutineRun(outcome: .completed))
        XCTAssertTrue(store.recordRoutineRun(outcome: .needsMoreTime, at: Date(timeIntervalSince1970: 1_700_000_000)))
        XCTAssertEqual(store.routineHistory[0].completedCount, 0)

        let originalStep = store.routines[0]
        store.toggleRoutineStep(originalStep)
        XCTAssertFalse(store.recordRoutineRun(outcome: .completed))
        for step in store.routines where !step.isComplete { store.toggleRoutineStep(step) }
        XCTAssertTrue(store.recordRoutineRun(outcome: .completed))
        XCTAssertEqual(store.routineHistory[0].completedCount, store.routines.count)
        XCTAssertEqual(store.routineHistory[1].steps[0].title, originalStep.title)
        XCTAssertFalse(store.routineHistory[1].steps[0].isComplete)

        var edited = store.routines[0]
        edited.title = "Changed later"
        XCTAssertTrue(store.saveRoutineStep(edited))
        XCTAssertEqual(store.routineHistory[0].steps[0].title, originalStep.title)
        XCTAssertEqual(CommunicationStore(storageURL: file).routineHistory.count, 2)

        let backup = try store.backupData()
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.routineHistory.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.routineHistory.count, 2)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.routineHistory, store.routineHistory)
        let removedID = restored.routineHistory[0].id
        restored.deleteRoutineRun(id: removedID)
        XCTAssertEqual(restored.routineHistory.count, 1)
        XCTAssertEqual(CommunicationStore(storageURL: directory.appendingPathComponent("restored.json")).routineHistory.count, 1)
    }

    func testOlderStoredDataLoadsWithoutRoutineHistory() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "routineHistory")
        let previousData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertTrue(try JSONDecoder().decode(StoredData.self, from: previousData).routineHistory.isEmpty)
    }

    func testCSVIncludesEveryStepAndEscapesNames() {
        let steps = [RoutineStep(title: "Brush, wash", symbol: "🪥", isComplete: true, durationSeconds: 300),
                     RoutineStep(title: "Say \"hello\"\nagain", symbol: "👋", isComplete: false)]
        let run = RoutineRun(outcome: .needsMoreTime, steps: steps,
                             recordedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let csv = String(decoding: RoutineHistoryCSV.data(for: [run]), as: UTF8.self)
        XCTAssertTrue(csv.contains("recorded_at,outcome,completed_steps,total_steps,step_number,step_title,step_completed,duration_minutes\r\n"))
        XCTAssertTrue(csv.contains("Needed more time,1,2,1,\"Brush, wash\",Yes,5\r\n"))
        XCTAssertTrue(csv.contains("Needed more time,1,2,2,\"Say \"\"hello\"\"\nagain\",No,\r\n"))
        XCTAssertEqual(csv.components(separatedBy: "Needed more time").count - 1, 2)
    }
}
