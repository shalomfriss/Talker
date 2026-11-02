import XCTest
@testable import OpenVoice

final class FirstThenSessionTests: XCTestCase {
    func testSessionAdvancesAndResetsWithoutChangingSavedRoutine() {
        let original = [RoutineStep(title: "Shoes", symbol: "👟", isComplete: true),
                        RoutineStep(title: "Bus", symbol: "🚌"),
                        RoutineStep(title: "School", symbol: "🏫")]
        let template = RoutineTemplate(name: "Morning", steps: original)
        var session = FirstThenSession(template: template)
        XCTAssertEqual(session.current?.title, "Shoes")
        XCTAssertEqual(session.next?.title, "Bus")
        XCTAssertEqual(session.completedCount, 0)
        XCTAssertTrue(session.steps.allSatisfy { !$0.isComplete })
        XCTAssertNotEqual(session.steps[0].id, template.steps[0].id)

        XCTAssertTrue(session.advance())
        XCTAssertEqual(session.current?.title, "Bus")
        XCTAssertEqual(session.next?.title, "School")
        XCTAssertTrue(session.advance())
        XCTAssertEqual(session.current?.title, "School")
        XCTAssertNil(session.next)
        XCTAssertTrue(session.advance())
        XCTAssertNil(session.current)
        XCTAssertFalse(session.advance())
        XCTAssertEqual(template.steps.map(\.title), original.map(\.title))

        session.reset()
        XCTAssertEqual(session.completedCount, 0)
        XCTAssertEqual(session.current?.title, "Shoes")
    }

    func testChecklistCompletionCanBeOutOfOrderAndSnapshotTracksMarks() {
        let template = RoutineTemplate(name: "Morning", steps: [
            RoutineStep(title: "Shoes", symbol: "👟"),
            RoutineStep(title: "Bus", symbol: "🚌"),
            RoutineStep(title: "School", symbol: "🏫")
        ])
        var session = FirstThenSession(template: template)
        let later = session.steps[2]
        XCTAssertTrue(session.setComplete(later.id, to: true))
        XCTAssertEqual(session.completedCount, 1)
        XCTAssertEqual(session.current?.title, "Shoes")
        XCTAssertEqual(session.next?.title, "Bus")
        XCTAssertEqual(session.completedSteps.map(\.title), ["School"])
        XCTAssertEqual(session.snapshotSteps.map(\.isComplete), [false, false, true])
        XCTAssertTrue(session.advance())
        XCTAssertEqual(session.current?.title, "Bus")
        XCTAssertNil(session.next)
        XCTAssertTrue(session.setComplete(later.id, to: false))
        XCTAssertEqual(session.next?.title, "School")
        XCTAssertFalse(session.setComplete(UUID(), to: true))
        session.reset()
        XCTAssertEqual(session.completedCount, 0)
        XCTAssertTrue(session.snapshotSteps.allSatisfy { !$0.isComplete })
    }

    func testOldTemplateDefaultsToAutomaticLayout() throws {
        let template = RoutineTemplate(name: "Morning", steps: [RoutineStep(title: "Shoes", symbol: "👟")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(template)) as? [String: Any])
        object.removeValue(forKey: "firstThenLayout")
        object.removeValue(forKey: "boardMode")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try JSONDecoder().decode(RoutineTemplate.self, from: oldData).firstThenLayout, .automatic)
        XCTAssertEqual(try JSONDecoder().decode(RoutineTemplate.self, from: oldData).boardMode, .firstThen)
    }

    @MainActor
    func testBoardLayoutStaysWithTemplateProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("board-layout.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        XCTAssertTrue(store.saveRoutineTemplate(name: "Morning"))
        let templateID = store.routineTemplates[0].id
        store.setRoutineTemplateLayout(id: templateID, layout: .stacked)
        store.setRoutineTemplateMode(id: templateID, mode: .checklist)
        XCTAssertEqual(CommunicationStore(storageURL: file).routineTemplates[0].firstThenLayout, .stacked)
        XCTAssertEqual(CommunicationStore(storageURL: file).routineTemplates[0].boardMode, .checklist)
        let backup = try store.backupData()
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.routineTemplates.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.routineTemplates[0].firstThenLayout, .stacked)
        XCTAssertEqual(store.routineTemplates[0].boardMode, .checklist)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.routineTemplates[0].firstThenLayout, .stacked)
        XCTAssertEqual(restored.routineTemplates[0].boardMode, .checklist)
    }
}
