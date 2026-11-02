import Foundation
import UserNotifications

@MainActor
enum RoutineReminderManager {
    private static let center = UNUserNotificationCenter.current()
    private static let identifierPrefix = "openvoice.routine."

    static func hasPermission(requestIfNeeded: Bool) async throws -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined where requestIfNeeded:
            return try await center.requestAuthorization(options: [.alert, .sound])
        default:
            return false
        }
    }

    static func schedule(_ plan: RoutineReminderPlan) async throws {
        guard plan.reminder.isValid else { return }
        let identifiers = plan.reminder.requestIdentifiers(profileID: plan.profileID)
        do {
            for (weekday, identifier) in zip(plan.reminder.weekdays, identifiers) {
                let content = UNMutableNotificationContent()
                content.title = "Time for \(plan.templateName)"
                content.body = "Open \(plan.profileName)'s First/Then board."
                content.userInfo = ["openvoice.profileID": plan.profileID.uuidString,
                                    "openvoice.templateID": plan.reminder.templateID.uuidString]
                if plan.reminder.playsSound { content.sound = .default }
                var date = DateComponents()
                date.calendar = Calendar.current
                date.weekday = weekday
                date.hour = plan.reminder.hour
                date.minute = plan.reminder.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                           trigger: trigger))
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            throw error
        }
    }

    static func cancel(_ reminder: RoutineReminder, profileID: UUID) {
        let identifiers = reminder.requestIdentifiers(profileID: profileID)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    static func restore(_ plans: [RoutineReminderPlan]) async {
        guard (try? await hasPermission(requestIfNeeded: false)) == true else { return }
        let desired = Set(plans.flatMap { $0.reminder.requestIdentifiers(profileID: $0.profileID) })
        let pending = await center.pendingNotificationRequests()
        let obsolete = pending.map(\.identifier).filter {
            $0.hasPrefix(identifierPrefix) && !desired.contains($0)
        }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: obsolete) }
        for plan in plans { try? await schedule(plan) }
    }
}
