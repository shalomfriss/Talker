import SwiftUI

struct WeeklyActivityReminderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let activityID: UUID
    let weekday: Int
    @State private var time = Date.now
    @State private var playsSound = false
    @State private var saving = false
    @State private var status: String?
    @State private var errorMessage: String?

    private var activity: WeeklyActivity? {
        store.weeklyPlan.activities(on: weekday).first { $0.id == activityID }
    }

    private var existingReminder: WeeklyActivityReminder? {
        store.weeklyPlan.reminders.first { $0.weekday == weekday && $0.activityID == activityID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let activity {
                    Section {
                        Text("Remind me about \(activity.option.label) every \(Calendar.current.weekdaySymbols[weekday - 1]).")
                            .foregroundStyle(.secondary)
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("weekly-reminder-time")
                        Toggle("Play a sound", isOn: $playsSound)
                            .accessibilityIdentifier("weekly-reminder-sound")
                        Button(existingReminder == nil ? "Set reminder" : "Save reminder") {
                            Task { await saveReminder(activityName: activity.option.label) }
                        }
                        .disabled(saving)
                        .accessibilityIdentifier("weekly-reminder-save")
                        if let status {
                            Text(status).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if existingReminder != nil {
                        Section {
                            Button("Remove reminder", role: .destructive) {
                                store.deleteWeeklyReminder(activityID: activityID, on: weekday)
                                dismiss()
                            }
                            .accessibilityIdentifier("weekly-reminder-delete")
                        }
                    }
                } else {
                    ContentUnavailableView("Activity not found", systemImage: "bell.slash")
                }
            }
            .navigationTitle("Activity reminder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if let existingReminder {
                time = Calendar.current.date(bySettingHour: existingReminder.hour,
                                             minute: existingReminder.minute, second: 0,
                                             of: .now) ?? .now
                playsSound = existingReminder.playsSound
            }
        }
        .alert("Reminder unavailable", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveReminder(activityName: String) async {
        saving = true
        status = "Checking notification permission…"
        defer {
            saving = false
            status = nil
        }
        let profileID = store.activeProfileID
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = WeeklyActivityReminder(activityID: activityID, weekday: weekday,
                                              hour: components.hour ?? 0, minute: components.minute ?? 0,
                                              playsSound: playsSound)
        do {
            guard try await RoutineReminderManager.hasPermission(requestIfNeeded: true) else {
                errorMessage = "Allow notifications for Open Voice in Settings to schedule this reminder."
                return
            }
            guard profileID == store.activeProfileID,
                  store.weeklyPlan.activities(on: weekday).contains(where: { $0.id == activityID }) else { return }
            status = "Scheduling reminder…"
            try await WeeklyReminderManager.schedule(WeeklyReminderPlan(profileID: profileID,
                                                                          activityName: activityName,
                                                                          reminder: reminder))
            if store.setWeeklyReminder(reminder) {
                dismiss()
            } else {
                WeeklyReminderManager.cancel(reminder, profileID: profileID)
                errorMessage = "This reminder could not be saved."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
