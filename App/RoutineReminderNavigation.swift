import SwiftUI
import UserNotifications

struct RoutineReminderTarget: Equatable {
    let profileID: UUID
    let templateID: UUID
}

struct WeeklyReminderTarget: Identifiable, Equatable {
    let profileID: UUID
    let weekday: Int
    let activityID: UUID
    var id: UUID { activityID }
}

struct CalendarReminderTarget: Identifiable, Equatable {
    let profileID: UUID
    let eventID: UUID
    let date: Date
    var id: UUID { eventID }
}

@MainActor
final class RoutineReminderNavigation: ObservableObject {
    static let shared = RoutineReminderNavigation()
    @Published var target: RoutineReminderTarget?
    @Published var weeklyTarget: WeeklyReminderTarget?
    @Published var calendarTarget: CalendarReminderTarget?
    private init() {}
}

final class RoutineReminderAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let profileString = info["openvoice.profileID"] as? String,
              let profileID = UUID(uuidString: profileString) else { return }
        if let templateString = info["openvoice.templateID"] as? String,
           let templateID = UUID(uuidString: templateString) {
            await MainActor.run {
                RoutineReminderNavigation.shared.target = RoutineReminderTarget(profileID: profileID,
                                                                                templateID: templateID)
            }
        } else if let weekday = info["openvoice.weekday"] as? Int,
                  let activityString = info["openvoice.activityID"] as? String,
                  let activityID = UUID(uuidString: activityString) {
            await MainActor.run {
                RoutineReminderNavigation.shared.weeklyTarget = WeeklyReminderTarget(
                    profileID: profileID, weekday: weekday, activityID: activityID
                )
            }
        } else if let eventString = info["openvoice.calendarEventID"] as? String,
                  let eventID = UUID(uuidString: eventString) {
            let notificationDate = response.notification.date
            await MainActor.run {
                RoutineReminderNavigation.shared.calendarTarget = CalendarReminderTarget(
                    profileID: profileID, eventID: eventID, date: notificationDate
                )
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
