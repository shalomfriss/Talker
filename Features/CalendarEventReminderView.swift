import SwiftUI

struct CalendarEventReminderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    @State private var time = Date.now.addingTimeInterval(600)
    @State private var playsSound = false
    @State private var saving = false
    @State private var status: String?
    @State private var errorMessage: String?

    private var event: CalendarEvent? {
        store.visualCalendar.events.first { $0.id == eventID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let event {
                    Section {
                        Text("Remind me when \(event.option.label) is planned.")
                            .foregroundStyle(.secondary)
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("calendar-reminder-time")
                        Toggle("Play a sound", isOn: $playsSound)
                            .accessibilityIdentifier("calendar-reminder-sound")
                        Button(event.reminder == nil ? "Set reminder" : "Save reminder") {
                            Task { await saveReminder() }
                        }
                        .disabled(saving)
                        .accessibilityIdentifier("calendar-reminder-save")
                        if let status {
                            Text(status).font(.footnote).foregroundStyle(.secondary)
                        }
                        if event.repeatRule != .never && event.startDate > Date.now {
                            Text("The first reminder is set for the first event date. Open Voice refreshes repeating reminders when opened after that date.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if event.reminder != nil {
                        Section {
                            Button("Remove reminder", role: .destructive) {
                                store.deleteCalendarReminder(eventID: eventID)
                                dismiss()
                            }
                            .accessibilityIdentifier("calendar-reminder-delete")
                        }
                    }
                } else {
                    ContentUnavailableView("Event not found", systemImage: "bell.slash")
                }
            }
            .navigationTitle("Event reminder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .onAppear {
            if let reminder = event?.reminder {
                time = Calendar.current.date(bySettingHour: reminder.hour,
                                             minute: reminder.minute, second: 0,
                                             of: .now) ?? .now
                playsSound = reminder.playsSound
            }
        }
        .alert("Reminder unavailable", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveReminder() async {
        guard var event else { return }
        saving = true
        status = "Checking notification permission…"
        defer { saving = false; status = nil }
        let profileID = store.activeProfileID
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = CalendarEventReminder(hour: parts.hour ?? 0,
                                             minute: parts.minute ?? 0,
                                             playsSound: playsSound)
        event.reminder = reminder
        do {
            guard try await RoutineReminderManager.hasPermission(requestIfNeeded: true) else {
                errorMessage = "Allow notifications for Open Voice in Settings to schedule this reminder."
                return
            }
            guard profileID == store.activeProfileID,
                  store.visualCalendar.events.contains(where: { $0.id == eventID }) else { return }
            status = "Scheduling reminder…"
            try await CalendarReminderManager.schedule(CalendarReminderPlan(profileID: profileID,
                                                                             event: event))
            if store.setCalendarReminder(reminder, eventID: eventID) {
                dismiss()
            } else {
                CalendarReminderManager.cancel(event, profileID: profileID)
                errorMessage = "This reminder could not be saved."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
