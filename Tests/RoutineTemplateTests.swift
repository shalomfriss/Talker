import XCTest
@testable import OpenVoice

final class RoutineTemplateTests: XCTestCase {
    @MainActor
    func testSavedRoutineCompletionAddsLinkedRewardTokenAndKeepsItAcrossBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("routine-rewards.json")
        let store = CommunicationStore(storageURL: file)
        let chart = try XCTUnwrap(store.addRewardChart(title: "Morning steps", reward: "Choose music",
                                                       targetTokens: 2))
        XCTAssertTrue(store.saveRoutineTemplate(name: "Morning reward"))
        let templateID = try XCTUnwrap(store.routineTemplates.last?.id)
        XCTAssertFalse(store.setRoutineTemplateRewardChart(id: templateID, chartID: UUID()))
        XCTAssertTrue(store.setRoutineTemplateRewardChart(id: templateID, chartID: chart.id))
        XCTAssertTrue(store.setRoutineTemplateRewardFrequency(id: templateID, frequency: .eachStep))
        XCTAssertEqual(store.routineTemplates.last?.rewardChartID, chart.id)
        XCTAssertEqual(store.routineTemplates.last?.rewardFrequency, .eachStep)
        XCTAssertEqual(store.awardRoutineCompletion(templateID: templateID)?.earnedTokens, 1)
        XCTAssertEqual(store.awardRoutineCompletion(templateID: templateID)?.earnedTokens, 2)
        XCTAssertNil(store.awardRoutineCompletion(templateID: templateID))
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 2)
        XCTAssertEqual(CommunicationStore(storageURL: file).routineTemplates.last?.rewardChartID, chart.id)
        XCTAssertEqual(CommunicationStore(storageURL: file).routineTemplates.last?.rewardFrequency, .eachStep)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.routineTemplates.last?.rewardChartID, chart.id)
        XCTAssertEqual(restored.routineTemplates.last?.rewardFrequency, .eachStep)
        XCTAssertEqual(restored.rewardCharts.first?.earnedTokens, 2)
        var backupObject = try XCTUnwrap(JSONSerialization.jsonObject(with: store.backupData()) as? [String: Any])
        backupObject["rewardCharts"] = []
        let missingChart = CommunicationStore(storageURL: directory.appendingPathComponent("missing-chart.json"))
        try missingChart.importBackup(JSONSerialization.data(withJSONObject: backupObject))
        XCTAssertNil(missingChart.routineTemplates.last?.rewardChartID)
        XCTAssertTrue(restored.deleteRewardChart(id: chart.id))
        XCTAssertNil(restored.routineTemplates.last?.rewardChartID)
        XCTAssertNil(restored.awardRoutineCompletion(templateID: templateID))
    }

    func testOlderSavedRoutineDefaultsToNoLinkedReward() throws {
        let template = RoutineTemplate(name: "Older routine", steps: [RoutineStep(title: "Go", symbol: "🚶")])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(template)) as? [String: Any])
        object.removeValue(forKey: "rewardChartID")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try JSONDecoder().decode(RoutineTemplate.self, from: data).rewardChartID)
    }

    @MainActor
    func testSavedRoutinePreservesMediaAndLoadsFreshStepsAcrossProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("routine-templates.json")
        let store = CommunicationStore(storageURL: file)
        let firstProfile = store.activeProfileID
        let choiceBoard = ChoiceBoard(title: "Morning choices", options: [
            ChoiceOption(label: "Cereal"), ChoiceOption(label: "Toast")
        ])
        XCTAssertTrue(store.saveChoiceBoard(choiceBoard))
        var first = store.routines[0]
        first.imageData = Data([1, 2, 3])
        first.audioData = Data([4, 5, 6])
        first.spokenText = "Please get dressed"
        first.durationSeconds = 60
        first.choiceBoardID = choiceBoard.id
        XCTAssertTrue(store.saveRoutineStep(first))
        store.toggleRoutineStep(first)
        XCTAssertTrue(store.saveRoutineTemplate(name: " Morning "))
        XCTAssertFalse(store.saveRoutineTemplate(name: "morning"))
        let template = try XCTUnwrap(store.routineTemplates.first)
        XCTAssertEqual(template.name, "Morning")
        XCTAssertFalse(template.steps[0].isComplete)
        XCTAssertEqual(template.steps[0].imageData, first.imageData)
        XCTAssertEqual(template.steps[0].audioData, first.audioData)
        XCTAssertEqual(template.steps[0].spokenText, first.spokenText)
        XCTAssertEqual(template.steps[0].durationSeconds, first.durationSeconds)
        XCTAssertEqual(template.steps[0].choiceBoardID, choiceBoard.id)

        store.addRoutineStep("Pack bag")
        XCTAssertTrue(store.loadRoutineTemplate(id: template.id))
        XCTAssertEqual(store.routines.count, template.steps.count)
        XCTAssertTrue(store.routines.allSatisfy { !$0.isComplete })
        XCTAssertNotEqual(store.routines[0].id, template.steps[0].id)
        XCTAssertEqual(store.routines[0].imageData, first.imageData)
        XCTAssertEqual(store.routines[0].audioData, first.audioData)
        XCTAssertEqual(store.routines[0].spokenText, first.spokenText)
        XCTAssertEqual(store.routines[0].durationSeconds, first.durationSeconds)
        XCTAssertEqual(store.routines[0].choiceBoardID, choiceBoard.id)

        XCTAssertEqual(CommunicationStore(storageURL: file).routineTemplates, store.routineTemplates)
        let backup = try store.backupData()
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.routineTemplates.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstProfile))
        XCTAssertEqual(store.routineTemplates.count, 1)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.routineTemplates, store.routineTemplates)
        XCTAssertEqual(restored.routineTemplates.first?.steps.first?.choiceBoardID, choiceBoard.id)
        store.deleteChoiceBoard(id: choiceBoard.id)
        XCTAssertNil(store.routines[0].choiceBoardID)
        XCTAssertNil(store.routineTemplates[0].steps[0].choiceBoardID)
    }

    @MainActor
    func testRoutineRejectsMissingChoiceBoard() {
        let store = CommunicationStore(storageURL:
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let step = RoutineStep(title: "Choose a snack", symbol: "🍎", choiceBoardID: UUID())
        XCTAssertFalse(store.saveRoutineStep(step))
        XCTAssertFalse(store.routines.contains { $0.id == step.id })
    }

    @MainActor
    func testBackupClearsChoiceLinksWhenBoardIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let board = ChoiceBoard(title: "Snack choices", options: [
            ChoiceOption(label: "Apple"), ChoiceOption(label: "Banana")
        ])
        XCTAssertTrue(source.saveChoiceBoard(board))
        XCTAssertTrue(source.saveRoutineStep(RoutineStep(title: "Pick a snack", symbol: "🍎",
            choiceBoardID: board.id)))
        XCTAssertTrue(source.saveRoutineTemplate(name: "Snack time"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: source.backupData()) as? [String: Any])
        object["choiceBoards"] = []
        let data = try JSONSerialization.data(withJSONObject: object)
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(data)
        XCTAssertNil(restored.routines.last?.choiceBoardID)
        XCTAssertNil(restored.routineTemplates.first?.steps.last?.choiceBoardID)
    }

    @MainActor
    func testSavedRoutineCanBeUpdatedRenamedAndDeleted() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("templates.json"))
        XCTAssertTrue(store.saveRoutineTemplate(name: "Morning"))
        XCTAssertTrue(store.saveRoutineTemplate(name: "Evening"))
        let firstID = store.routineTemplates[0].id
        XCTAssertFalse(store.renameRoutineTemplate(id: firstID, name: "evening"))
        XCTAssertFalse(store.renameRoutineTemplate(id: firstID, name: "  "))
        XCTAssertTrue(store.renameRoutineTemplate(id: firstID, name: "  Before school  "))
        XCTAssertEqual(store.routineTemplates[0].name, "Before school")
        store.addRoutineStep("Take keys")
        XCTAssertTrue(store.updateRoutineTemplate(id: firstID))
        XCTAssertEqual(store.routineTemplates[0].steps.last?.title, "Take keys")
        store.deleteRoutineTemplate(id: firstID)
        XCTAssertEqual(store.routineTemplates.map(\.name), ["Evening"])
        XCTAssertFalse(store.loadRoutineTemplate(id: firstID))
    }

    func testOlderStoredDataLoadsWithoutSavedRoutines() throws {
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "routineTemplates")
        let previousData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertTrue(try JSONDecoder().decode(StoredData.self, from: previousData).routineTemplates.isEmpty)
    }

    @MainActor
    func testRoutineRemindersPersistAcrossProfilesAndBackupAndDeleteWithTemplate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("reminders.json")
        let store = CommunicationStore(storageURL: file)
        XCTAssertTrue(store.saveRoutineTemplate(name: "Morning"))
        let template = try XCTUnwrap(store.routineTemplates.first)
        let reminder = RoutineReminder(templateID: template.id, weekdays: [2, 4, 2],
                                       hour: 8, minute: 30, playsSound: true)
        XCTAssertEqual(reminder.weekdays, [2, 4])
        XCTAssertTrue(store.addRoutineReminder(reminder))
        XCTAssertFalse(store.addRoutineReminder(reminder))
        XCTAssertEqual(CommunicationStore(storageURL: file).routineReminders, [reminder])
        let backup = try store.backupData()
        let originalProfileID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertTrue(store.routineReminders.isEmpty)
        XCTAssertTrue(store.switchProfile(to: originalProfileID))
        XCTAssertEqual(store.routineReminders, [reminder])
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(backup)
        XCTAssertEqual(restored.routineReminders, [reminder])
        store.deleteRoutineTemplate(id: template.id)
        XCTAssertTrue(store.routineReminders.isEmpty)
        XCTAssertTrue(CommunicationStore(storageURL: file).routineReminders.isEmpty)
    }

    func testRoutineReminderValidationAndOldBackupDecoding() throws {
        let templateID = UUID()
        XCTAssertFalse(RoutineReminder(templateID: templateID, weekdays: [], hour: 8, minute: 0).isValid)
        XCTAssertFalse(RoutineReminder(templateID: templateID, weekdays: [8], hour: 8, minute: 0).isValid)
        XCTAssertFalse(RoutineReminder(templateID: templateID, weekdays: [1], hour: 24, minute: 0).isValid)
        XCTAssertFalse(RoutineReminder(templateID: templateID, weekdays: [1], hour: 8, minute: 60).isValid)
        let stored = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                                phrases: StarterVocabulary.phrases, settings: AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        object.removeValue(forKey: "routineReminders")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertTrue(try JSONDecoder().decode(StoredData.self, from: data).routineReminders.isEmpty)
    }
}
