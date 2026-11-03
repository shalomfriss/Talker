import XCTest
@testable import OpenVoice

final class WeeklyPlanTests: XCTestCase {
    func testCompletionBelongsToOneDateAndCopyClearsIt() throws {
        let calendar = Calendar(identifier: .gregorian)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        let nextMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: monday))
        let activity = WeeklyActivity(option: ChoiceOption(label: "Go swimming"))
        var plan = WeeklyPlan()
        XCTAssertTrue(plan.add(activity, on: 2))
        plan.toggle(id: activity.id, on: 2, date: monday, calendar: calendar)
        XCTAssertTrue(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: monday, calendar: calendar))
        XCTAssertFalse(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: nextMonday, calendar: calendar))
        XCTAssertTrue(plan.copy(from: 2, to: 3))
        XCTAssertEqual(plan.activities(on: 3).count, 1)
        XCTAssertNotEqual(plan.activities(on: 3)[0].id, activity.id)
        XCTAssertNil(plan.activities(on: 3)[0].completedOn)
        plan.toggle(id: activity.id, on: 2, date: monday, calendar: calendar)
        XCTAssertFalse(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: monday, calendar: calendar))
    }

    func testWeeklyCompletionKeepsEachOccurrenceAndDecodesOlderRecords() throws {
        let calendar = Calendar(identifier: .gregorian)
        let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        let second = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: first))
        let activity = WeeklyActivity(option: ChoiceOption(label: "Library"))
        var plan = WeeklyPlan()
        XCTAssertTrue(plan.add(activity, on: 2))
        plan.toggle(id: activity.id, on: 2, date: first, calendar: calendar)
        plan.toggle(id: activity.id, on: 2, date: second, calendar: calendar)
        XCTAssertTrue(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: first, calendar: calendar))
        XCTAssertTrue(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: second, calendar: calendar))

        plan = try JSONDecoder().decode(WeeklyPlan.self, from: JSONEncoder().encode(plan))
        plan.toggle(id: activity.id, on: 2, date: first, calendar: calendar)
        XCTAssertFalse(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: first, calendar: calendar))
        XCTAssertTrue(try XCTUnwrap(plan.activities(on: 2).first).isComplete(on: second, calendar: calendar))

        let old = WeeklyActivity(option: ChoiceOption(label: "Legacy"), completedOn: first)
        let decoded = try JSONDecoder().decode(WeeklyActivity.self, from: JSONEncoder().encode(old))
        XCTAssertTrue(decoded.isComplete(on: first, calendar: calendar))
        XCTAssertFalse(decoded.isComplete(on: second, calendar: calendar))
    }

    func testOrderEditAndValidation() {
        var plan = WeeklyPlan()
        let first = WeeklyActivity(option: ChoiceOption(label: "Breakfast"))
        let second = WeeklyActivity(option: ChoiceOption(label: "School"))
        XCTAssertFalse(plan.add(first, on: 8))
        XCTAssertFalse(plan.add(WeeklyActivity(option: ChoiceOption(label: " ")), on: 2))
        XCTAssertTrue(plan.add(first, on: 2))
        XCTAssertTrue(plan.add(second, on: 2))
        XCTAssertTrue(plan.move(on: 2, from: IndexSet(integer: 0), to: 2))
        XCTAssertEqual(plan.activities(on: 2).map(\.option.label), ["School", "Breakfast"])
        var edited = first
        edited.option.label = "Morning meal"
        XCTAssertTrue(plan.update(edited, on: 2))
        XCTAssertEqual(plan.activities(on: 2)[1].option.label, "Morning meal")
        plan.delete(id: second.id, on: 2)
        XCTAssertEqual(plan.activities(on: 2).count, 1)
    }

    func testSavedTemplateReusesActivitiesWithoutCompletion() throws {
        let activity = WeeklyActivity(option: ChoiceOption(label: "Visit library"), completedOn: Date())
        var plan = WeeklyPlan()
        XCTAssertTrue(plan.add(activity, on: 4))
        XCTAssertTrue(plan.saveTemplate(title: "  Library day  ", from: 4))
        XCTAssertFalse(plan.saveTemplate(title: "library DAY", from: 4))
        let template = try XCTUnwrap(plan.templates.first)
        XCTAssertEqual(template.title, "Library day")
        XCTAssertTrue(plan.applyTemplate(id: template.id, to: 6))
        XCTAssertEqual(plan.activities(on: 6).first?.option.label, "Visit library")
        XCTAssertNil(plan.activities(on: 6).first?.completedOn)
        XCTAssertNotEqual(plan.activities(on: 6).first?.id, activity.id)

        let encoded = try JSONEncoder().encode(plan)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "templates")
        let olderPlan = try JSONDecoder().decode(WeeklyPlan.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(olderPlan.activities(on: 4).count, 1)
        XCTAssertTrue(olderPlan.templates.isEmpty)
    }

    func testWeeklyRemindersFollowCopiesAndTemplatesAndDecodeOldPlans() throws {
        var plan = WeeklyPlan()
        let activity = WeeklyActivity(option: ChoiceOption(label: "Go swimming"))
        XCTAssertTrue(plan.add(activity, on: 2))
        let reminder = WeeklyActivityReminder(activityID: activity.id, weekday: 2,
                                              hour: 15, minute: 45, playsSound: true)
        XCTAssertTrue(plan.setReminder(reminder))
        XCTAssertFalse(plan.setReminder(WeeklyActivityReminder(activityID: UUID(), weekday: 2,
                                                               hour: 15, minute: 45)))
        XCTAssertFalse(plan.setReminder(WeeklyActivityReminder(activityID: activity.id, weekday: 2,
                                                               hour: 24, minute: 0)))
        XCTAssertTrue(plan.copy(from: 2, to: 3))
        let copiedID = try XCTUnwrap(plan.activities(on: 3).first?.id)
        XCTAssertEqual(plan.reminders.first(where: { $0.weekday == 3 }),
                       WeeklyActivityReminder(activityID: copiedID, weekday: 3,
                                              hour: 15, minute: 45, playsSound: true))
        XCTAssertTrue(plan.saveTemplate(title: "Pool day", from: 2))
        let template = try XCTUnwrap(plan.templates.first)
        XCTAssertEqual(template.reminderSpecs.count, 1)
        XCTAssertTrue(plan.applyTemplate(id: template.id, to: 4))
        let appliedID = try XCTUnwrap(plan.activities(on: 4).first?.id)
        XCTAssertEqual(plan.reminders.first(where: { $0.weekday == 4 }),
                       WeeklyActivityReminder(activityID: appliedID, weekday: 4,
                                              hour: 15, minute: 45, playsSound: true))
        plan.delete(id: activity.id, on: 2)
        XCTAssertFalse(plan.reminders.contains(where: { $0.weekday == 2 }))

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object.removeValue(forKey: "reminders")
        var templates = try XCTUnwrap(object["templates"] as? [[String: Any]])
        templates[0].removeValue(forKey: "reminderSpecs")
        object["templates"] = templates
        let oldPlan = try JSONDecoder().decode(WeeklyPlan.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(oldPlan.reminders.isEmpty)
        XCTAssertTrue(try XCTUnwrap(oldPlan.templates.first).reminderSpecs.isEmpty)
    }

    @MainActor
    func testLinkedWeeklyActivityAwardsOncePerDateAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let chart = try XCTUnwrap(store.addRewardChart(title: "Practice", reward: "Choose music",
                                                       targetTokens: 2))
        let activity = WeeklyActivity(option: ChoiceOption(label: "Try a new word"),
                                      rewardChartID: chart.id)
        XCTAssertTrue(store.addWeeklyActivity(activity, on: 2))
        let calendar = Calendar(identifier: .gregorian)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        let nextMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: monday))
        let thirdMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: monday))

        store.toggleWeeklyActivity(id: activity.id, on: 2, date: monday)
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 1)
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: monday)
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: monday)
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 1)
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: nextMonday)
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 2)
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: thirdMonday)
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 2)
        XCTAssertFalse(try XCTUnwrap(store.weeklyPlan.activities(on: 2).first)
            .hasEarnedReward(on: thirdMonday))

        let relaunched = CommunicationStore(storageURL: file)
        XCTAssertEqual(relaunched.rewardCharts.first?.earnedTokens, 2)
        XCTAssertTrue(try XCTUnwrap(relaunched.weeklyPlan.activities(on: 2).first)
            .hasEarnedReward(on: monday))
        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.rewardCharts.first?.earnedTokens, 2)
        XCTAssertTrue(try XCTUnwrap(restored.weeklyPlan.activities(on: 2).first)
            .hasEarnedReward(on: nextMonday))

        XCTAssertTrue(store.startRewardChartAgain(id: chart.id))
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: thirdMonday)
        store.toggleWeeklyActivity(id: activity.id, on: 2, date: thirdMonday)
        XCTAssertEqual(store.rewardCharts.first?.earnedTokens, 1)
    }

    @MainActor
    func testWeeklyRewardLinksFollowCopiesAndTemplatesAndClearOnChartDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let chart = try XCTUnwrap(store.addRewardChart(title: "Morning", reward: "Play outside"))
        let activity = WeeklyActivity(option: ChoiceOption(label: "Get ready"), rewardChartID: chart.id)
        XCTAssertTrue(store.addWeeklyActivity(activity, on: 2))
        XCTAssertTrue(store.copyWeeklyDay(from: 2, to: 3))
        let copied = try XCTUnwrap(store.weeklyPlan.activities(on: 3).first)
        XCTAssertEqual(copied.rewardChartID, chart.id)
        XCTAssertNil(copied.rewardedDates)
        XCTAssertTrue(store.saveWeeklyTemplate(title: "Morning plan", from: 2))
        let template = try XCTUnwrap(store.weeklyPlan.templates.first)
        XCTAssertEqual(template.rewardChartIDs, [chart.id])
        XCTAssertTrue(store.applyWeeklyTemplate(id: template.id, to: 4))
        XCTAssertEqual(store.weeklyPlan.activities(on: 4).first?.rewardChartID, chart.id)
        XCTAssertTrue(store.deleteRewardChart(id: chart.id))
        XCTAssertNil(store.weeklyPlan.activities(on: 2).first?.rewardChartID)
        XCTAssertNil(store.weeklyPlan.activities(on: 3).first?.rewardChartID)
        XCTAssertNil(store.weeklyPlan.activities(on: 4).first?.rewardChartID)
        XCTAssertEqual(store.weeklyPlan.templates.first?.rewardChartIDs, [nil])
    }

    func testOlderWeeklyRewardRecordsDecodeWithoutLinks() throws {
        let chartID = UUID()
        let activity = WeeklyActivity(option: ChoiceOption(label: "Library"), rewardChartID: chartID)
        let template = WeeklyPlanTemplate(title: "Library day", options: [activity.option],
                                          rewardChartIDs: [chartID])
        var activityObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(activity))
                                           as? [String: Any])
        activityObject.removeValue(forKey: "rewardChartID")
        activityObject.removeValue(forKey: "rewardedDates")
        let oldActivity = try JSONDecoder().decode(WeeklyActivity.self,
            from: JSONSerialization.data(withJSONObject: activityObject))
        XCTAssertNil(oldActivity.rewardChartID)
        XCTAssertNil(oldActivity.rewardedDates)

        var templateObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(template))
                                           as? [String: Any])
        templateObject.removeValue(forKey: "rewardChartIDs")
        let oldTemplate = try JSONDecoder().decode(WeeklyPlanTemplate.self,
            from: JSONSerialization.data(withJSONObject: templateObject))
        XCTAssertTrue(oldTemplate.rewardChartIDs.isEmpty)
    }

    @MainActor
    func testWeeklyPlanStaysWithProfileAndSurvivesBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        let store = CommunicationStore(storageURL: file)
        let firstID = store.activeProfileID
        let sourceWord = try XCTUnwrap(store.items.first(where: { $0.label == "go" }))
        let activity = WeeklyActivity(option: ChoiceOption(item: sourceWord))
        XCTAssertTrue(store.addWeeklyActivity(activity, on: 2))
        let reminder = WeeklyActivityReminder(activityID: activity.id, weekday: 2,
                                              hour: 8, minute: 15)
        XCTAssertTrue(store.setWeeklyReminder(reminder))
        XCTAssertTrue(store.saveWeeklyTemplate(title: "School morning", from: 2))
        let template = try XCTUnwrap(store.weeklyPlan.templates.first)
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertTrue(store.weeklyPlan.activities(on: 2).isEmpty)
        XCTAssertTrue(store.weeklyPlan.templates.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.weeklyPlan.activities(on: 2), [activity])
        XCTAssertEqual(store.weeklyPlan.reminders, [reminder])
        XCTAssertEqual(store.weeklyPlan.templates, [template])
        XCTAssertEqual(CommunicationStore(storageURL: file).weeklyPlan.activities(on: 2), [activity])
        let imported = CommunicationStore(storageURL: directory.appendingPathComponent("imported.json"))
        try imported.importBackup(store.backupData())
        XCTAssertEqual(imported.weeklyPlan.activities(on: 2), [activity])
        XCTAssertEqual(imported.weeklyPlan.reminders, [reminder])
        XCTAssertEqual(imported.weeklyPlan.templates, [template])
    }

    @MainActor
    func testCalendarPINProtectsWeeklyPlanEditsButKeepsCompletionAvailable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("weekly-lock.json"))
        let profileID = store.activeProfileID
        defer { CalendarEditingPINStore.delete(for: profileID) }
        let first = WeeklyActivity(option: ChoiceOption(label: "School"))
        let second = WeeklyActivity(option: ChoiceOption(label: "Library"))
        XCTAssertTrue(store.addWeeklyActivity(first, on: 2))
        XCTAssertTrue(store.addWeeklyActivity(second, on: 2))
        let reminder = WeeklyActivityReminder(activityID: first.id, weekday: 2, hour: 9, minute: 0)
        XCTAssertTrue(store.setWeeklyReminder(reminder))
        XCTAssertTrue(store.saveWeeklyTemplate(title: "Monday plan", from: 2))
        let templateID = try XCTUnwrap(store.weeklyPlan.templates.first?.id)
        try store.enableCalendarEditingLock(pin: "4826")

        XCTAssertFalse(store.addWeeklyActivity(WeeklyActivity(option: ChoiceOption(label: "Park")), on: 2))
        var changed = first
        changed.option.label = "Changed"
        XCTAssertFalse(store.updateWeeklyActivity(changed, on: 2))
        store.moveWeeklyActivities(on: 2, from: IndexSet(integer: 0), to: 2)
        store.deleteWeeklyActivity(id: first.id, on: 2)
        XCTAssertEqual(store.weeklyPlan.activities(on: 2), [first, second])
        XCTAssertFalse(store.copyWeeklyDay(from: 2, to: 3))
        XCTAssertFalse(store.applyWeeklyTemplate(id: templateID, to: 3))
        XCTAssertTrue(store.weeklyPlan.activities(on: 3).isEmpty)
        XCTAssertFalse(store.saveWeeklyTemplate(title: "Another", from: 2))
        store.deleteWeeklyTemplate(id: templateID)
        XCTAssertEqual(store.weeklyPlan.templates.first?.id, templateID)
        XCTAssertFalse(store.setWeeklyReminder(WeeklyActivityReminder(activityID: second.id,
                                                                      weekday: 2, hour: 10, minute: 0)))
        store.deleteWeeklyReminder(activityID: first.id, on: 2)
        XCTAssertEqual(store.weeklyPlan.reminders, [reminder])

        let monday = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        store.toggleWeeklyActivity(id: first.id, on: 2, date: monday)
        XCTAssertTrue(try XCTUnwrap(store.weeklyPlan.activities(on: 2).first).isComplete(on: monday))
        XCTAssertTrue(store.unlockCalendarEditing(pin: "4826"))
        XCTAssertTrue(store.updateWeeklyActivity(changed, on: 2))
    }
}
