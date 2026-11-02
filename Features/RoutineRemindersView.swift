import SwiftUI

struct RoutineRemindersView: View {
    @EnvironmentObject private var store: CommunicationStore
    let templateID: UUID
    @State private var time = Date.now
    @State private var weekdays: Set<Int> = Set(1...7)
    @State private var playsSound = false
    @State private var saving = false
    @State private var savingStatus: String?
    @State private var message: String?

    private var template: RoutineTemplate? {
        store.routineTemplates.first { $0.id == templateID }
    }

    private var reminders: [RoutineReminder] {
        store.routineReminders.filter { $0.templateID == templateID }
    }

    private var orderedWeekdays: [(number: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return (1...7).map { ($0, symbols[$0 - 1]) }
    }

    var body: some View {
        List {
            if let template {
                Section("New reminder") {
                    Text("Get a notification to open \(template.name)'s First/Then board.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("routine-reminder-time")
                    Toggle("Play a sound", isOn: $playsSound)
                        .accessibilityIdentifier("routine-reminder-sound")
                    ForEach(orderedWeekdays, id: \.number) { weekday in
                        Toggle(weekday.name, isOn: Binding(
                            get: { weekdays.contains(weekday.number) },
                            set: { selected in
                                if selected { weekdays.insert(weekday.number) }
                                else { weekdays.remove(weekday.number) }
                            }
                        ))
                        .accessibilityIdentifier("routine-reminder-day-\(weekday.number)")
                    }
                    Button("Save reminder", systemImage: "bell.badge") {
                        Task { await saveReminder() }
                    }
                    .disabled(weekdays.isEmpty || saving)
                    .accessibilityIdentifier("routine-reminder-save")
                    if let savingStatus {
                        Text(savingStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Scheduled reminders") {
                    if reminders.isEmpty {
                        Text("No reminders yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(reminders) { reminder in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary(for: reminder))
                                Text(reminder.playsSound ? "With sound" : "Silent")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Delete reminder", systemImage: "trash", role: .destructive) {
                                store.deleteRoutineReminder(id: reminder.id)
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("routine-reminder-delete")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Routine not found", systemImage: "bell.slash")
            }
        }
        .navigationTitle("Routine reminders")
        .alert("Reminder unavailable", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func summary(for reminder: RoutineReminder) -> String {
        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute
        let date = Calendar.current.date(from: components) ?? .now
        let timeText = date.formatted(date: .omitted, time: .shortened)
        let days = orderedWeekdays.filter { reminder.weekdays.contains($0.number) }.map(\.name)
        return "\(days.joined(separator: ", ")) at \(timeText)"
    }

    private func saveReminder() async {
        guard let template, !weekdays.isEmpty else { return }
        saving = true
        savingStatus = "Checking notification permission…"
        defer {
            saving = false
            savingStatus = nil
        }
        let profileID = store.activeProfileID
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = RoutineReminder(templateID: templateID, weekdays: Array(weekdays),
                                       hour: components.hour ?? 0, minute: components.minute ?? 0,
                                       playsSound: playsSound)
        do {
            guard try await RoutineReminderManager.hasPermission(requestIfNeeded: true) else {
                message = "Allow notifications for Open Voice in Settings to schedule this reminder."
                return
            }
            guard profileID == store.activeProfileID,
                  store.routineTemplates.contains(where: { $0.id == templateID }) else { return }
            savingStatus = "Scheduling reminder…"
            try await RoutineReminderManager.schedule(RoutineReminderPlan(
                profileID: profileID, profileName: store.activeProfileName,
                templateName: template.name, reminder: reminder
            ))
            if !store.addRoutineReminder(reminder) {
                RoutineReminderManager.cancel(reminder, profileID: profileID)
                message = "This reminder could not be saved."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
