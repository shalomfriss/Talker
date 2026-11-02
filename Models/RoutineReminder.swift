import Foundation

struct RoutineReminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var templateID: UUID
    var weekdays: [Int]
    var hour: Int
    var minute: Int
    var playsSound: Bool = false

    init(templateID: UUID, weekdays: [Int], hour: Int, minute: Int, playsSound: Bool = false) {
        self.templateID = templateID
        self.weekdays = Array(Set(weekdays)).sorted()
        self.hour = hour
        self.minute = minute
        self.playsSound = playsSound
    }

    var isValid: Bool {
        !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) } &&
            (0...23).contains(hour) && (0...59).contains(minute)
    }

    func requestIdentifiers(profileID: UUID) -> [String] {
        weekdays.map { "openvoice.routine.\(profileID.uuidString).\(id.uuidString).\($0)" }
    }
}

struct RoutineReminderPlan {
    var profileID: UUID
    var profileName: String
    var templateName: String
    var reminder: RoutineReminder
}
