import Foundation
import UserNotifications

struct WeeklyReminderPlan {
    var profileID: UUID
    var activityName: String
    var reminder: WeeklyActivityReminder
}

@MainActor
enum WeeklyReminderManager {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "openvoice.weekly."

    static func schedule(_ plan: WeeklyReminderPlan) async throws {
        guard plan.reminder.isValid else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for \(plan.activityName)"
        content.body = "Open today's visual plan."
        content.userInfo = ["openvoice.profileID": plan.profileID.uuidString,
                            "openvoice.weekday": plan.reminder.weekday,
                            "openvoice.activityID": plan.reminder.activityID.uuidString]
        if plan.reminder.playsSound { content.sound = .default }
        var date = DateComponents()
        date.calendar = Calendar.current
        date.weekday = plan.reminder.weekday
        date.hour = plan.reminder.hour
        date.minute = plan.reminder.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let identifier = plan.reminder.requestIdentifier(profileID: plan.profileID)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                   trigger: trigger))
    }

    static func cancel(_ reminder: WeeklyActivityReminder, profileID: UUID) {
        let identifier = reminder.requestIdentifier(profileID: profileID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    static func restore(_ plans: [WeeklyReminderPlan]) async {
        guard (try? await RoutineReminderManager.hasPermission(requestIfNeeded: false)) == true else { return }
        let desired = Set(plans.map { $0.reminder.requestIdentifier(profileID: $0.profileID) })
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.map(\.identifier).filter {
            $0.hasPrefix(identifierPrefix) && !desired.contains($0)
        }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
        for plan in plans { try? await schedule(plan) }
    }
}
