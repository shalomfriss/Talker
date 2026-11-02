import Foundation
import UserNotifications

struct CalendarReminderPlan {
    var profileID: UUID
    var event: CalendarEvent
}

enum CalendarReminderError: LocalizedError {
    case invalidTime
    case noFutureOccurrence

    var errorDescription: String? {
        switch self {
        case .invalidTime: "Choose a valid reminder time."
        case .noFutureOccurrence: "Choose a future event date and reminder time."
        }
    }
}

enum CalendarReminderSchedule {
    static func trigger(for event: CalendarEvent, now: Date = .now,
                        calendar: Calendar = .current) throws -> (DateComponents, Bool) {
        guard let reminder = event.reminder, reminder.isValid else { throw CalendarReminderError.invalidTime }
        let start = calendar.startOfDay(for: event.startDate)
        let today = calendar.startOfDay(for: now)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone

        if event.repeatRule != .never && start <= today {
            switch event.repeatRule {
            case .weekly: components.weekday = calendar.component(.weekday, from: start)
            case .yearly:
                components.month = calendar.component(.month, from: start)
                components.day = calendar.component(.day, from: start)
            case .never: break
            }
            components.hour = reminder.hour
            components.minute = reminder.minute
            return (components, true)
        }

        guard let first = event.nextOccurrence(onOrAfter: now, calendar: calendar),
              let fire = calendar.date(bySettingHour: reminder.hour, minute: reminder.minute,
                                       second: 0, of: first), fire > now else {
            throw CalendarReminderError.noFutureOccurrence
        }
        let exact = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        components.year = exact.year
        components.month = exact.month
        components.day = exact.day
        components.hour = exact.hour
        components.minute = exact.minute
        return (components, false)
    }
}

@MainActor
enum CalendarReminderManager {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "openvoice.calendar."

    static func schedule(_ plan: CalendarReminderPlan) async throws {
        guard let reminder = plan.event.reminder else { return }
        let (components, repeats) = try CalendarReminderSchedule.trigger(for: plan.event)
        let content = UNMutableNotificationContent()
        content.title = "Time for \(plan.event.option.label)"
        content.body = "Open the visual calendar to see what is planned."
        content.userInfo = ["openvoice.profileID": plan.profileID.uuidString,
                            "openvoice.calendarEventID": plan.event.id.uuidString]
        if reminder.playsSound { content.sound = .default }
        let identifier = reminder.requestIdentifier(profileID: plan.profileID, eventID: plan.event.id)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                   trigger: UNCalendarNotificationTrigger(
                                                    dateMatching: components, repeats: repeats)))
    }

    static func cancel(_ event: CalendarEvent, profileID: UUID) {
        guard let reminder = event.reminder else { return }
        let identifier = reminder.requestIdentifier(profileID: profileID, eventID: event.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func restore(_ plans: [CalendarReminderPlan]) async {
        guard (try? await RoutineReminderManager.hasPermission(requestIfNeeded: false)) == true else { return }
        let desired = Set(plans.compactMap { plan in
            plan.event.reminder?.requestIdentifier(profileID: plan.profileID, eventID: plan.event.id)
        })
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.map(\.identifier).filter {
            $0.hasPrefix(identifierPrefix) && !desired.contains($0)
        }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
        for plan in plans {
            do { try await schedule(plan) }
            catch CalendarReminderError.noFutureOccurrence { cancel(plan.event, profileID: plan.profileID) }
            catch { }
        }
    }
}
