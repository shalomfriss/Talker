import Foundation

enum CalendarRepeatRule: String, Codable, CaseIterable, Identifiable {
    case never
    case weekly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Does not repeat"
        case .weekly: "Every week"
        case .yearly: "Every year"
        }
    }
}

enum CalendarDayNumberSize: String, Codable, CaseIterable, Identifiable {
    case standard, large, largest

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var pointSize: Double {
        switch self {
        case .standard: 17
        case .large: 22
        case .largest: 27
        }
    }
}

struct CalendarAppearance: Codable, Equatable {
    var dayNumberSize: CalendarDayNumberSize = .standard
    var plannedLabel: String? = nil
    var completedLabel: String? = nil
    var showsPlannedLabel: Bool? = nil
    var showsCompletedLabel: Bool? = nil
    var plannedAudioData: Data? = nil
    var completedAudioData: Data? = nil

    func title(forCompleted completed: Bool, language: String) -> String {
        let custom = (completed ? completedLabel : plannedLabel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let custom, !custom.isEmpty { return custom }
        if language == "es" { return completed ? "Terminado" : "Por hacer" }
        return completed ? "Finished" : "To do"
    }

    func cleaned() -> CalendarAppearance {
        var copy = self
        copy.plannedLabel = Self.cleanLabel(plannedLabel)
        copy.completedLabel = Self.cleanLabel(completedLabel)
        if copy.plannedLabel == nil { copy.plannedAudioData = nil }
        if copy.completedLabel == nil { copy.completedAudioData = nil }
        return copy
    }

    func audioData(forCompleted completed: Bool) -> Data? {
        guard Self.cleanLabel(completed ? completedLabel : plannedLabel) != nil else { return nil }
        return completed ? completedAudioData : plannedAudioData
    }

    func showsLabel(forCompleted completed: Bool) -> Bool {
        (completed ? showsCompletedLabel : showsPlannedLabel) ?? true
    }

    private static func cleanLabel(_ label: String?) -> String? {
        let text = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : String(text.prefix(40))
    }
}

struct CalendarEventReminder: Codable, Equatable {
    var hour: Int
    var minute: Int
    var playsSound: Bool = false

    var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }

    func requestIdentifier(profileID: UUID, eventID: UUID) -> String {
        "openvoice.calendar.\(profileID.uuidString).\(eventID.uuidString)"
    }
}

struct CalendarEvent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var option: ChoiceOption
    var startDate: Date
    var repeatRule: CalendarRepeatRule = .never
    var showsCountdown: Bool = false
    var completedOn: [Date] = []
    var reminder: CalendarEventReminder? = nil
    var colorHex: String? = nil

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        guard day >= start else { return false }
        switch repeatRule {
        case .never: return calendar.isDate(day, inSameDayAs: start)
        case .weekly:
            return calendar.component(.weekday, from: day) == calendar.component(.weekday, from: start)
        case .yearly:
            return calendar.component(.month, from: day) == calendar.component(.month, from: start)
                && calendar.component(.day, from: day) == calendar.component(.day, from: start)
        }
    }

    func nextOccurrence(onOrAfter date: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let lowerBound = max(today, start)
        switch repeatRule {
        case .never: return start >= today ? start : nil
        case .weekly:
            let target = calendar.component(.weekday, from: start)
            let current = calendar.component(.weekday, from: lowerBound)
            return calendar.date(byAdding: .day, value: (target - current + 7) % 7, to: lowerBound)
        case .yearly:
            let month = calendar.component(.month, from: start)
            let day = calendar.component(.day, from: start)
            let year = calendar.component(.year, from: lowerBound)
            for candidateYear in year...(year + 8) {
                guard let candidate = calendar.date(from: DateComponents(year: candidateYear, month: month, day: day)),
                      calendar.component(.month, from: candidate) == month,
                      calendar.component(.day, from: candidate) == day else { continue }
                if candidate >= lowerBound { return candidate }
            }
            return nil
        }
    }

    func daysUntilNext(from date: Date, calendar: Calendar = .current) -> Int? {
        guard let next = nextOccurrence(onOrAfter: date, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: next).day
    }

    func isComplete(on date: Date, calendar: Calendar = .current) -> Bool {
        completedOn.contains { calendar.isDate($0, inSameDayAs: date) }
    }
}

struct VisualCalendar: Codable, Equatable {
    var events: [CalendarEvent] = []
    var appearance: CalendarAppearance? = nil
    var editingLocked: Bool? = nil

    var effectiveAppearance: CalendarAppearance { appearance ?? CalendarAppearance() }
    var isEditingLocked: Bool { editingLocked == true }

    func events(on date: Date, calendar: Calendar = .current) -> [CalendarEvent] {
        events.filter { $0.occurs(on: date, calendar: calendar) }
    }

    @discardableResult
    mutating func add(_ event: CalendarEvent) -> Bool {
        guard !event.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !event.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !events.contains(where: { $0.id == event.id }) else { return false }
        events.append(event)
        return true
    }

    @discardableResult
    mutating func update(_ event: CalendarEvent) -> Bool {
        guard let index = events.firstIndex(where: { $0.id == event.id }),
              !event.option.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !event.option.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        events[index] = event
        return true
    }

    mutating func delete(id: UUID) {
        events.removeAll { $0.id == id }
    }

    mutating func toggleComplete(id: UUID, on date: Date, calendar: Calendar = .current) {
        guard let index = events.firstIndex(where: { $0.id == id }),
              events[index].occurs(on: date, calendar: calendar) else { return }
        if events[index].isComplete(on: date, calendar: calendar) {
            events[index].completedOn.removeAll { calendar.isDate($0, inSameDayAs: date) }
        } else {
            events[index].completedOn.append(calendar.startOfDay(for: date))
        }
    }
}

enum CalendarEditingAccessError: LocalizedError {
    case locked

    var errorDescription: String? {
        "Unlock calendar editing before changing its PIN."
    }
}
