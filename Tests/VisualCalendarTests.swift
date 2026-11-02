import XCTest
@testable import OpenVoice

final class VisualCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testOneTimeWeeklyAndYearlyEventsMatchOnlyTheirOccurrences() {
        let option = ChoiceOption(label: "Visit")
        let start = date(2026, 10, 31)
        let once = CalendarEvent(option: option, startDate: start)
        XCTAssertFalse(once.occurs(on: date(2026, 10, 30), calendar: calendar))
        XCTAssertTrue(once.occurs(on: start, calendar: calendar))
        XCTAssertFalse(once.occurs(on: date(2026, 11, 7), calendar: calendar))

        var weekly = once
        weekly.repeatRule = .weekly
        XCTAssertTrue(weekly.occurs(on: date(2026, 11, 7), calendar: calendar))
        XCTAssertFalse(weekly.occurs(on: date(2026, 11, 8), calendar: calendar))
        XCTAssertEqual(weekly.daysUntilNext(from: date(2026, 11, 1), calendar: calendar), 6)

        var yearly = once
        yearly.repeatRule = .yearly
        XCTAssertTrue(yearly.occurs(on: date(2027, 10, 31), calendar: calendar))
        XCTAssertFalse(yearly.occurs(on: date(2027, 11, 1), calendar: calendar))
        XCTAssertEqual(yearly.daysUntilNext(from: date(2027, 10, 30), calendar: calendar), 1)
    }

    func testLeapDayWaitsForTheNextRealOccurrence() {
        let event = CalendarEvent(option: ChoiceOption(label: "Leap day"),
                                  startDate: date(2024, 2, 29), repeatRule: .yearly)
        XCTAssertFalse(event.occurs(on: date(2025, 2, 28), calendar: calendar))
        XCTAssertEqual(event.nextOccurrence(onOrAfter: date(2025, 1, 1), calendar: calendar),
                       date(2028, 2, 29))
    }

    func testRepeatedEventCompletionBelongsToTheChosenDay() {
        let event = CalendarEvent(option: ChoiceOption(label: "Library"),
                                  startDate: date(2026, 10, 31), repeatRule: .weekly)
        var plan = VisualCalendar()
        XCTAssertTrue(plan.add(event))
        XCTAssertEqual(plan.events(on: date(2026, 11, 7), calendar: calendar).count, 1)
        plan.toggleComplete(id: event.id, on: date(2026, 11, 7), calendar: calendar)
        XCTAssertTrue(plan.events[0].isComplete(on: date(2026, 11, 7), calendar: calendar))
        XCTAssertFalse(plan.events[0].isComplete(on: date(2026, 11, 14), calendar: calendar))
        plan.toggleComplete(id: event.id, on: date(2026, 11, 7), calendar: calendar)
        XCTAssertFalse(plan.events[0].isComplete(on: date(2026, 11, 7), calendar: calendar))
        plan.toggleComplete(id: event.id, on: date(2026, 11, 8), calendar: calendar)
        XCTAssertFalse(plan.events[0].isComplete(on: date(2026, 11, 8), calendar: calendar))
    }

    func testReminderScheduleMatchesOneTimeAndRepeatingEvents() throws {
        let reminder = CalendarEventReminder(hour: 9, minute: 30, playsSound: true)
        var event = CalendarEvent(option: ChoiceOption(label: "Visit"),
                                  startDate: date(2026, 11, 12), reminder: reminder)
        let oneTime = try CalendarReminderSchedule.trigger(for: event,
            now: date(2026, 11, 1), calendar: calendar)
        XCTAssertFalse(oneTime.1)
        XCTAssertEqual(oneTime.0.year, 2026)
        XCTAssertEqual(oneTime.0.month, 11)
        XCTAssertEqual(oneTime.0.day, 12)
        XCTAssertEqual(oneTime.0.hour, 9)
        XCTAssertEqual(oneTime.0.minute, 30)

        event.repeatRule = .weekly
        let firstFuture = try CalendarReminderSchedule.trigger(for: event,
            now: date(2026, 11, 1), calendar: calendar)
        XCTAssertFalse(firstFuture.1)
        XCTAssertEqual(firstFuture.0.day, 12)
        let ongoing = try CalendarReminderSchedule.trigger(for: event,
            now: date(2026, 11, 13), calendar: calendar)
        XCTAssertTrue(ongoing.1)
        XCTAssertEqual(ongoing.0.weekday, calendar.component(.weekday, from: event.startDate))
        XCTAssertNil(ongoing.0.day)

        event.repeatRule = .yearly
        let annual = try CalendarReminderSchedule.trigger(for: event,
            now: date(2027, 1, 1), calendar: calendar)
        XCTAssertTrue(annual.1)
        XCTAssertEqual(annual.0.month, 11)
        XCTAssertEqual(annual.0.day, 12)
        XCTAssertNil(annual.0.year)
    }

    func testReminderRejectsPastOneTimeEventAndInvalidHour() {
        var event = CalendarEvent(option: ChoiceOption(label: "Visit"),
                                  startDate: date(2026, 10, 31),
                                  reminder: CalendarEventReminder(hour: 9, minute: 30))
        XCTAssertThrowsError(try CalendarReminderSchedule.trigger(for: event,
            now: date(2026, 11, 1), calendar: calendar))
        event.reminder = CalendarEventReminder(hour: 25, minute: 0)
        XCTAssertThrowsError(try CalendarReminderSchedule.trigger(for: event,
            now: date(2026, 10, 1), calendar: calendar))
    }

    @MainActor
    func testCalendarEventsStayWithProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let event = CalendarEvent(option: ChoiceOption(label: "Grandma visit", symbol: "👵",
                                                       imageData: Data([1, 2, 3]), audioData: Data([4, 5])),
                                  startDate: date(2026, 11, 12), showsCountdown: true,
                                  reminder: CalendarEventReminder(hour: 10, minute: 15, playsSound: true))
        XCTAssertTrue(store.addCalendarEvent(event))
        let firstID = store.activeProfileID
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertTrue(store.visualCalendar.events.isEmpty)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.visualCalendar.events, [event])

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.visualCalendar.events, [event])
        XCTAssertEqual(restored.visualCalendar.events.first?.reminder?.hour, 10)
    }

    func testOldBackupWithoutCalendarStartsEmpty() throws {
        let store = StoredData(items: StarterVocabulary.items, routines: StarterVocabulary.routines,
                               phrases: StarterVocabulary.phrases, settings: .init())
        let data = try JSONEncoder().encode(store)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "visualCalendar")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(StoredData.self, from: oldData)
        XCTAssertTrue(decoded.visualCalendar.events.isEmpty)
    }

    func testOldCalendarDecodesWithoutAppearanceOrEventColor() throws {
        let event = CalendarEvent(option: ChoiceOption(label: "Library"), startDate: date(2026, 10, 31))
        let data = try JSONEncoder().encode(VisualCalendar(events: [event]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "appearance")
        var events = try XCTUnwrap(object["events"] as? [[String: Any]])
        events[0].removeValue(forKey: "colorHex")
        object["events"] = events
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(VisualCalendar.self, from: oldData)
        XCTAssertEqual(decoded.events.count, 1)
        XCTAssertNil(decoded.events[0].colorHex)
        XCTAssertEqual(decoded.effectiveAppearance.dayNumberSize, .standard)
        XCTAssertFalse(decoded.isEditingLocked)
    }

    func testOlderAppearanceWithoutRecordingsAndEmptyLabelCleanup() throws {
        let appearance = CalendarAppearance(plannedLabel: "Next", completedLabel: "Done")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(appearance)) as? [String: Any])
        object.removeValue(forKey: "plannedAudioData")
        object.removeValue(forKey: "completedAudioData")
        let decoded = try JSONDecoder().decode(CalendarAppearance.self,
                                               from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.audioData(forCompleted: false))
        XCTAssertNil(decoded.audioData(forCompleted: true))
        XCTAssertEqual(decoded.title(forCompleted: false, language: "en"), "Next")
        XCTAssertTrue(decoded.showsLabel(forCompleted: false))
        XCTAssertTrue(decoded.showsLabel(forCompleted: true))

        let hidden = CalendarAppearance(plannedLabel: "Next", completedLabel: "Done",
                                        showsPlannedLabel: false, showsCompletedLabel: false)
        XCTAssertFalse(hidden.showsLabel(forCompleted: false))
        XCTAssertFalse(hidden.showsLabel(forCompleted: true))

        let stale = CalendarAppearance(plannedLabel: "  ", completedLabel: nil,
                                       plannedAudioData: Data([1]), completedAudioData: Data([2])).cleaned()
        XCTAssertNil(stale.plannedAudioData)
        XCTAssertNil(stale.completedAudioData)
    }

    @MainActor
    func testCalendarEditPINProtectsChangesButKeepsCompletionAvailable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("calendar-lock.json")
        let store = CommunicationStore(storageURL: url)
        let profileID = store.activeProfileID
        defer { CalendarEditingPINStore.delete(for: profileID) }
        let event = CalendarEvent(option: ChoiceOption(label: "Park"), startDate: date(2026, 10, 31))
        XCTAssertTrue(store.addCalendarEvent(event))
        XCTAssertThrowsError(try store.enableCalendarEditingLock(pin: "12"))
        try store.enableCalendarEditingLock(pin: "4826")
        XCTAssertTrue(store.calendarEditingBlocked)
        XCTAssertFalse(store.addCalendarEvent(CalendarEvent(option: ChoiceOption(label: "School"),
                                                             startDate: event.startDate)))
        var changed = event
        changed.option.label = "Changed"
        XCTAssertFalse(store.updateCalendarEvent(changed))
        store.deleteCalendarEvent(id: event.id)
        XCTAssertEqual(store.visualCalendar.events, [event])
        store.setCalendarAppearance(CalendarAppearance(dayNumberSize: .largest))
        XCTAssertEqual(store.visualCalendar.effectiveAppearance.dayNumberSize, .standard)
        XCTAssertFalse(store.setCalendarReminder(CalendarEventReminder(hour: 9, minute: 0), eventID: event.id))

        store.toggleCalendarEvent(id: event.id, on: event.startDate)
        XCTAssertTrue(store.visualCalendar.events[0].isComplete(on: event.startDate))
        XCTAssertFalse(store.unlockCalendarEditing(pin: "1111"))
        XCTAssertTrue(store.calendarEditingBlocked)
        XCTAssertTrue(store.unlockCalendarEditing(pin: "4826"))
        XCTAssertFalse(store.calendarEditingBlocked)
        XCTAssertTrue(store.updateCalendarEvent(changed))
        store.lockCalendarEditing()
        XCTAssertTrue(store.calendarEditingBlocked)

        let relaunched = CommunicationStore(storageURL: url)
        XCTAssertTrue(relaunched.calendarEditingBlocked)
        XCTAssertTrue(relaunched.unlockCalendarEditing(pin: "4826"))
        XCTAssertTrue(relaunched.disableCalendarEditingLock())
        XCTAssertFalse(relaunched.visualCalendar.isEditingLocked)
        XCTAssertTrue(CalendarEditingPINStore.isMissing(for: profileID))
    }

    @MainActor
    func testCalendarEditLockIsProfileSpecificAndBackupDoesNotStrandPIN() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let firstID = store.activeProfileID
        defer { CalendarEditingPINStore.delete(for: firstID) }
        try store.enableCalendarEditingLock(pin: "4826")
        XCTAssertTrue(store.addProfile("Second communicator"))
        XCTAssertFalse(store.visualCalendar.isEditingLocked)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertTrue(store.calendarEditingBlocked)

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertFalse(restored.visualCalendar.isEditingLocked)
        XCTAssertFalse(restored.calendarEditingBlocked)
    }

    @MainActor
    func testCalendarAppearanceAndColorPersistPerProfileAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CommunicationStore(storageURL: directory.appendingPathComponent("source.json"))
        let appearance = CalendarAppearance(dayNumberSize: .largest,
                                            plannedLabel: "  Getting ready  ",
                                            completedLabel: "  All done  ",
                                            showsPlannedLabel: true,
                                            showsCompletedLabel: false,
                                            plannedAudioData: Data([1, 2, 3]),
                                            completedAudioData: Data([4, 5, 6]))
        store.setCalendarAppearance(appearance)
        let event = CalendarEvent(option: ChoiceOption(label: "Park"),
                                  startDate: date(2026, 10, 31), colorHex: "#3CA95B")
        XCTAssertTrue(store.addCalendarEvent(event))
        let firstID = store.activeProfileID
        XCTAssertEqual(store.visualCalendar.effectiveAppearance.plannedLabel, "Getting ready")
        XCTAssertEqual(store.visualCalendar.effectiveAppearance.audioData(forCompleted: false), Data([1, 2, 3]))
        XCTAssertTrue(store.addProfile("Other communicator"))
        XCTAssertEqual(store.visualCalendar.effectiveAppearance.dayNumberSize, .standard)
        XCTAssertTrue(store.switchProfile(to: firstID))
        XCTAssertEqual(store.visualCalendar.events.first?.colorHex, "#3CA95B")

        let restored = CommunicationStore(storageURL: directory.appendingPathComponent("restored.json"))
        try restored.importBackup(store.backupData())
        XCTAssertEqual(restored.visualCalendar.effectiveAppearance.dayNumberSize, .largest)
        XCTAssertEqual(restored.visualCalendar.effectiveAppearance.title(forCompleted: false, language: "es"),
                       "Getting ready")
        XCTAssertEqual(restored.visualCalendar.effectiveAppearance.audioData(forCompleted: false), Data([1, 2, 3]))
        XCTAssertEqual(restored.visualCalendar.effectiveAppearance.audioData(forCompleted: true), Data([4, 5, 6]))
        XCTAssertFalse(restored.visualCalendar.effectiveAppearance.showsLabel(forCompleted: true))
        XCTAssertEqual(restored.visualCalendar.events.first?.colorHex, "#3CA95B")
    }
}
