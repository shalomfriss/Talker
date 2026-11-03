import Foundation

struct WeeklyActivity: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var option: ChoiceOption
    var completedOn: Date? = nil
    var completedDates: [Date]? = nil
    var rewardChartID: UUID? = nil
    var rewardedDates: [Date]? = nil

    func isComplete(on date: Date, calendar: Calendar = .current) -> Bool {
        if let completedOn, calendar.isDate(completedOn, inSameDayAs: date) { return true }
        return completedDates?.contains { calendar.isDate($0, inSameDayAs: date) } == true
    }

    func hasEarnedReward(on date: Date, calendar: Calendar = .current) -> Bool {
        rewardedDates?.contains { calendar.isDate($0, inSameDayAs: date) } == true
    }
}

struct WeeklyDay: Codable, Equatable {
    var weekday: Int
    var activities: [WeeklyActivity] = []
}

struct WeeklyPlanTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var options: [ChoiceOption]
    var reminderSpecs: [WeeklyTemplateReminder] = []
    var rewardChartIDs: [UUID?] = []

    init(title: String, options: [ChoiceOption], reminderSpecs: [WeeklyTemplateReminder] = [],
         rewardChartIDs: [UUID?] = []) {
        self.title = title
        self.options = options
        self.reminderSpecs = reminderSpecs
        self.rewardChartIDs = rewardChartIDs
    }

    private enum CodingKeys: String, CodingKey { case id, title, options, reminderSpecs, rewardChartIDs }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        options = try values.decode([ChoiceOption].self, forKey: .options)
        reminderSpecs = try values.decodeIfPresent([WeeklyTemplateReminder].self, forKey: .reminderSpecs) ?? []
        rewardChartIDs = try values.decodeIfPresent([UUID?].self, forKey: .rewardChartIDs) ?? []
    }
}

struct WeeklyTemplateReminder: Codable, Equatable {
    var activityIndex: Int
    var hour: Int
    var minute: Int
    var playsSound: Bool
}

struct WeeklyActivityReminder: Identifiable, Codable, Equatable {
    var activityID: UUID
    var weekday: Int
    var hour: Int
    var minute: Int
    var playsSound: Bool = false

    var id: UUID { activityID }
    var isValid: Bool {
        (1...7).contains(weekday) && (0...23).contains(hour) && (0...59).contains(minute)
    }

    func requestIdentifier(profileID: UUID) -> String {
        "openvoice.weekly.\(profileID.uuidString).\(weekday).\(activityID.uuidString)"
    }
}

struct WeeklyPlan: Codable, Equatable {
    var days: [WeeklyDay] = (1...7).map { WeeklyDay(weekday: $0) }
    var templates: [WeeklyPlanTemplate] = []
    var reminders: [WeeklyActivityReminder] = []

    private enum CodingKeys: String, CodingKey { case days, templates, reminders }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedDays = try values.decodeIfPresent([WeeklyDay].self, forKey: .days) ?? []
        days = (1...7).map { weekday in
            savedDays.first(where: { $0.weekday == weekday }) ?? WeeklyDay(weekday: weekday)
        }
        templates = try values.decodeIfPresent([WeeklyPlanTemplate].self, forKey: .templates) ?? []
        reminders = (try values.decodeIfPresent([WeeklyActivityReminder].self, forKey: .reminders) ?? [])
            .filter { reminder in
                reminder.isValid && days.contains(where: { day in
                    day.weekday == reminder.weekday && day.activities.contains(where: { $0.id == reminder.activityID })
                })
            }
    }

    func activities(on weekday: Int) -> [WeeklyActivity] {
        days.first(where: { $0.weekday == weekday })?.activities ?? []
    }

    @discardableResult
    mutating func add(_ activity: WeeklyActivity, on weekday: Int) -> Bool {
        guard let index = days.firstIndex(where: { $0.weekday == weekday }),
              !activity.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activity.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        days[index].activities.append(activity)
        return true
    }

    @discardableResult
    mutating func update(_ activity: WeeklyActivity, on weekday: Int) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.weekday == weekday }),
              let activityIndex = days[dayIndex].activities.firstIndex(where: { $0.id == activity.id }),
              !activity.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !activity.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        days[dayIndex].activities[activityIndex] = activity
        return true
    }

    mutating func delete(id: UUID, on weekday: Int) {
        guard let index = days.firstIndex(where: { $0.weekday == weekday }) else { return }
        days[index].activities.removeAll { $0.id == id }
        reminders.removeAll { $0.weekday == weekday && $0.activityID == id }
    }

    @discardableResult
    mutating func setReminder(_ reminder: WeeklyActivityReminder) -> Bool {
        guard reminder.isValid,
              activities(on: reminder.weekday).contains(where: { $0.id == reminder.activityID }) else { return false }
        reminders.removeAll { $0.weekday == reminder.weekday && $0.activityID == reminder.activityID }
        reminders.append(reminder)
        return true
    }

    mutating func deleteReminder(activityID: UUID, on weekday: Int) {
        reminders.removeAll { $0.weekday == weekday && $0.activityID == activityID }
    }

    mutating func toggle(id: UUID, on weekday: Int, date: Date, calendar: Calendar = .current) {
        guard let dayIndex = days.firstIndex(where: { $0.weekday == weekday }),
              let activityIndex = days[dayIndex].activities.firstIndex(where: { $0.id == id }) else { return }
        let activity = days[dayIndex].activities[activityIndex]
        if let completedOn = activity.completedOn, calendar.isDate(completedOn, inSameDayAs: date) {
            days[dayIndex].activities[activityIndex].completedOn = nil
        } else if activity.completedDates?.contains(where: { calendar.isDate($0, inSameDayAs: date) }) == true {
            days[dayIndex].activities[activityIndex].completedDates?.removeAll {
                calendar.isDate($0, inSameDayAs: date)
            }
        } else {
            days[dayIndex].activities[activityIndex].completedDates =
                (activity.completedDates ?? []) + [calendar.startOfDay(for: date)]
        }
    }

    @discardableResult
    mutating func markRewarded(id: UUID, on weekday: Int, date: Date,
                              calendar: Calendar = .current) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.weekday == weekday }),
              let activityIndex = days[dayIndex].activities.firstIndex(where: { $0.id == id }),
              days[dayIndex].activities[activityIndex].isComplete(on: date, calendar: calendar),
              !days[dayIndex].activities[activityIndex].hasEarnedReward(on: date, calendar: calendar)
        else { return false }
        days[dayIndex].activities[activityIndex].rewardedDates =
            (days[dayIndex].activities[activityIndex].rewardedDates ?? []) + [calendar.startOfDay(for: date)]
        return true
    }

    mutating func removeMissingRewardCharts(validIDs: Set<UUID>) {
        for dayIndex in days.indices {
            for activityIndex in days[dayIndex].activities.indices {
                if let id = days[dayIndex].activities[activityIndex].rewardChartID,
                   !validIDs.contains(id) {
                    days[dayIndex].activities[activityIndex].rewardChartID = nil
                    days[dayIndex].activities[activityIndex].rewardedDates = nil
                }
            }
        }
        for index in templates.indices {
            templates[index].rewardChartIDs = templates[index].rewardChartIDs.map { id in
                id.flatMap { validIDs.contains($0) ? $0 : nil }
            }
        }
    }

    @discardableResult
    mutating func move(on weekday: Int, from source: IndexSet, to destination: Int) -> Bool {
        guard let index = days.firstIndex(where: { $0.weekday == weekday }),
              destination >= 0, destination <= days[index].activities.count,
              source.allSatisfy({ days[index].activities.indices.contains($0) }) else { return false }
        let moved = source.map { days[index].activities[$0] }
        for position in source.sorted(by: >) { days[index].activities.remove(at: position) }
        let adjusted = destination - source.filter { $0 < destination }.count
        days[index].activities.insert(contentsOf: moved, at: adjusted)
        return true
    }

    @discardableResult
    mutating func copy(from source: Int, to destination: Int) -> Bool {
        guard source != destination,
              let sourceIndex = days.firstIndex(where: { $0.weekday == source }),
              let targetIndex = days.firstIndex(where: { $0.weekday == destination }) else { return false }
        let sourceActivities = days[sourceIndex].activities
        let copied = sourceActivities.map { WeeklyActivity(option: $0.option, rewardChartID: $0.rewardChartID) }
        reminders.removeAll { $0.weekday == destination }
        for (sourceActivity, copiedActivity) in zip(sourceActivities, copied) {
            if let reminder = reminders.first(where: { $0.weekday == source && $0.activityID == sourceActivity.id }) {
                reminders.append(WeeklyActivityReminder(activityID: copiedActivity.id, weekday: destination,
                                                        hour: reminder.hour, minute: reminder.minute,
                                                        playsSound: reminder.playsSound))
            }
        }
        days[targetIndex].activities = copied
        return true
    }

    @discardableResult
    mutating func saveTemplate(title: String, from weekday: Int) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = activities(on: weekday).map(\.option)
        guard !clean.isEmpty, !options.isEmpty,
              !templates.contains(where: { $0.title.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        let reminderSpecs = activities(on: weekday).enumerated().compactMap { index, activity -> WeeklyTemplateReminder? in
            guard let reminder = reminders.first(where: { $0.weekday == weekday && $0.activityID == activity.id }) else { return nil }
            return WeeklyTemplateReminder(activityIndex: index, hour: reminder.hour,
                                          minute: reminder.minute, playsSound: reminder.playsSound)
        }
        templates.append(WeeklyPlanTemplate(title: clean, options: options,
                                            reminderSpecs: reminderSpecs,
                                            rewardChartIDs: activities(on: weekday).map(\.rewardChartID)))
        return true
    }

    @discardableResult
    mutating func applyTemplate(id: UUID, to weekday: Int) -> Bool {
        guard let template = templates.first(where: { $0.id == id }),
              let dayIndex = days.firstIndex(where: { $0.weekday == weekday }) else { return false }
        let applied = template.options.enumerated().map { index, option in
            WeeklyActivity(option: option,
                           rewardChartID: template.rewardChartIDs.indices.contains(index)
                           ? template.rewardChartIDs[index] : nil)
        }
        reminders.removeAll { $0.weekday == weekday }
        for spec in template.reminderSpecs where applied.indices.contains(spec.activityIndex) {
            let reminder = WeeklyActivityReminder(activityID: applied[spec.activityIndex].id, weekday: weekday,
                                                  hour: spec.hour, minute: spec.minute,
                                                  playsSound: spec.playsSound)
            if reminder.isValid { reminders.append(reminder) }
        }
        days[dayIndex].activities = applied
        return true
    }

    mutating func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
    }
}
