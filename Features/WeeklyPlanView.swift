import SwiftUI

struct WeeklyPlanView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var selectedWeekday: Int
    private let highlightedActivityID: UUID?
    @State private var showingNewActivity = false
    @State private var showingEditProtection = false
    @State private var showingWordPicker = false
    @State private var editingActivity: WeeklyActivity?
    @State private var reminderSelection: WeeklyReminderSelection?
    @State private var pendingCopyTarget: Int?
    @State private var pendingTemplate: WeeklyPlanTemplate?
    @State private var showingTemplateNameAlert = false
    @State private var templateName = ""
    @State private var templateErrorMessage: String?
    @State private var today = Date()

    init(initialWeekday: Int? = nil, highlightedActivityID: UUID? = nil) {
        _selectedWeekday = State(initialValue: initialWeekday ?? Calendar.current.component(.weekday, from: Date()))
        self.highlightedActivityID = highlightedActivityID
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? calendar.startOfDay(for: today)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var selectedDate: Date {
        weekDates.first(where: { Calendar.current.component(.weekday, from: $0) == selectedWeekday }) ?? today
    }

    private var activities: [WeeklyActivity] { store.weeklyPlan.activities(on: selectedWeekday) }

    var body: some View {
        ScrollViewReader { scrollProxy in
        List {
            Section {
                Text("Plan each day with pictures and words. The plan repeats each week; completed steps reset for the new week. Tap an activity to say it and add it to your message.")
                    .foregroundStyle(.secondary)
                if store.calendarEditingBlocked {
                    Label("Editing is locked. You can still speak and mark activities done.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("weekly-plan-locked")
                }
            }
            Section("This week") {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(weekDates, id: \.self) { date in
                            let weekday = Calendar.current.component(.weekday, from: date)
                            WeekDayButton(date: date, weekday: weekday,
                                          isSelected: weekday == selectedWeekday) {
                                selectedWeekday = weekday
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.headline)
            }
            Section("Activities") {
                if activities.isEmpty {
                    ContentUnavailableView("No activities yet", systemImage: "calendar.badge.plus",
                                           description: Text("Add a word or a personal activity for this day."))
                }
                ForEach(activities) { activity in
                    activityRow(activity)
                        .id(activity.id)
                }
                .onMove { source, destination in
                    store.moveWeeklyActivities(on: selectedWeekday, from: source, to: destination)
                }
                Button("Add a personal activity", systemImage: "plus") { showingNewActivity = true }
                    .disabled(store.calendarEditingBlocked)
                    .accessibilityIdentifier("add-weekly-activity")
                Button("Add from my words", systemImage: "text.bubble") { showingWordPicker = true }
                    .disabled(store.calendarEditingBlocked)
            }
            Section("Reuse this day") {
                Menu("Copy these activities to another day", systemImage: "doc.on.doc") {
                    ForEach(weekDates, id: \.self) { date in
                        let weekday = Calendar.current.component(.weekday, from: date)
                        if weekday != selectedWeekday {
                            Button(date.formatted(.dateTime.weekday(.wide))) {
                                pendingCopyTarget = weekday
                            }
                        }
                    }
                }
                .disabled(activities.isEmpty || store.calendarEditingBlocked)
                Text("Copying replaces the other day’s activities and reminders. The original day stays as it is.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Saved day templates") {
                Button("Save this day as a template", systemImage: "square.and.arrow.down") {
                    templateName = "\(dayName(selectedWeekday)) plan"
                    showingTemplateNameAlert = true
                }
                .disabled(activities.isEmpty || store.calendarEditingBlocked)
                .accessibilityIdentifier("save-weekly-template")
                ForEach(store.weeklyPlan.templates) { template in
                    HStack {
                        Button { pendingTemplate = template } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.title).font(.headline)
                                Text("\(template.options.count) activities")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(store.calendarEditingBlocked)
                        .accessibilityLabel("Use \(template.title) on \(dayName(selectedWeekday))")
                        Menu {
                            if store.calendarEditingBlocked {
                                Button("Unlock editing", systemImage: "lock.open") { showingEditProtection = true }
                            } else {
                                Button("Delete template", systemImage: "trash", role: .destructive) {
                                    store.deleteWeeklyTemplate(id: template.id)
                                }
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                            .accessibilityLabel("Options for \(template.title)")
                    }
                }
            }
        }
        .navigationTitle("Weekly plan")
        .toolbar {
            Button(store.calendarEditingBlocked ? "Unlock plan editing" : "Plan edit protection",
                   systemImage: store.calendarEditingBlocked ? "lock.fill" : "lock.open") {
                showingEditProtection = true
            }
            .accessibilityIdentifier("weekly-plan-protection-open")
            if !store.calendarEditingBlocked { EditButton() }
        }
        .sheet(isPresented: $showingEditProtection) { CalendarEditProtectionView() }
        .sheet(isPresented: $showingNewActivity) {
            WeeklyActivityEditorView(activity: nil, weekday: selectedWeekday)
        }
        .sheet(item: $editingActivity) {
            WeeklyActivityEditorView(activity: $0, weekday: selectedWeekday)
        }
        .sheet(item: $reminderSelection) { selection in
            WeeklyActivityReminderView(activityID: selection.activityID, weekday: selection.weekday)
        }
        .sheet(isPresented: $showingWordPicker) {
            SceneWordPickerView { item in
                _ = store.addWeeklyActivity(WeeklyActivity(option: ChoiceOption(item: item)), on: selectedWeekday)
            }
        }
        .confirmationDialog("Replace \(dayName(pendingCopyTarget)) with \(dayName(selectedWeekday))?",
                            isPresented: Binding(
            get: { pendingCopyTarget != nil }, set: { if !$0 { pendingCopyTarget = nil } }
        )) {
            Button("Replace activities") {
                if let pendingCopyTarget { _ = store.copyWeeklyDay(from: selectedWeekday, to: pendingCopyTarget) }
                pendingCopyTarget = nil
            }
            Button("Cancel", role: .cancel) { pendingCopyTarget = nil }
        }
        .confirmationDialog("Use \(pendingTemplate?.title ?? "template") on \(dayName(selectedWeekday))?",
                            isPresented: Binding(
            get: { pendingTemplate != nil }, set: { if !$0 { pendingTemplate = nil } }
        )) {
            Button("Replace activities") {
                if let pendingTemplate { _ = store.applyWeeklyTemplate(id: pendingTemplate.id, to: selectedWeekday) }
                pendingTemplate = nil
            }
            Button("Cancel", role: .cancel) { pendingTemplate = nil }
        } message: {
            Text("This replaces the day’s activities and reminders. The saved template stays available.")
        }
        .alert("Save day template", isPresented: $showingTemplateNameAlert) {
            TextField("Template name", text: $templateName)
            Button("Save") {
                if !store.saveWeeklyTemplate(title: templateName, from: selectedWeekday) {
                    templateErrorMessage = "Choose a new name for a day with activities."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save these activities to use on any day later.")
        }
        .alert("Could not save template", isPresented: Binding(
            get: { templateErrorMessage != nil }, set: { if !$0 { templateErrorMessage = nil } }
        )) {
            Button("OK") { templateErrorMessage = nil }
        } message: {
            Text(templateErrorMessage ?? "Choose a different name.")
        }
        .onChange(of: store.activeProfileID) { _, _ in
            selectedWeekday = Calendar.current.component(.weekday, from: Date())
            editingActivity = nil
            reminderSelection = nil
            pendingCopyTarget = nil
            pendingTemplate = nil
            showingEditProtection = false
        }
        .onChange(of: store.calendarEditingBlocked) { _, blocked in
            if blocked {
                showingNewActivity = false
                showingWordPicker = false
                editingActivity = nil
                reminderSelection = nil
                pendingCopyTarget = nil
                pendingTemplate = nil
                showingTemplateNameAlert = false
            }
        }
        .onDisappear { store.lockCalendarEditing() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            today = Date()
        }
        .task {
            if let highlightedActivityID {
                await Task.yield()
                scrollProxy.scrollTo(highlightedActivityID, anchor: .center)
            }
        }
        }
    }

    private func activityRow(_ activity: WeeklyActivity) -> some View {
        let option = activity.option.resolved(using: store.items)
        let item = option.communicationItem
        let done = activity.isComplete(on: selectedDate)
        return HStack(spacing: 12) {
            Button {
                store.select(item)
                if item.audioData == nil && !store.settings.speakOnTap {
                    store.speak(store.displayMessage(for: item))
                }
            } label: {
                HStack(spacing: 12) {
                    if let data = option.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityHidden(true)
                    } else {
                        Text(option.symbol).font(.largeTitle)
                            .frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                    }
                    Text(store.displayLabel(for: item))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Say \(store.displayLabel(for: item))")
            Button {
                store.toggleWeeklyActivity(id: activity.id, on: selectedWeekday, date: selectedDate)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(done ? .green : .secondary)
            }
            .accessibilityLabel("\(done ? "Mark not done" : "Mark done"): \(store.displayLabel(for: item))")
            if store.weeklyPlan.reminders.contains(where: { $0.weekday == selectedWeekday && $0.activityID == activity.id }) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.indigo)
                    .accessibilityLabel("Reminder set")
            }
            Menu {
                if store.calendarEditingBlocked {
                    Button("Unlock editing", systemImage: "lock.open") { showingEditProtection = true }
                } else {
                    Button("Edit", systemImage: "pencil") {
                        var current = activity
                        current.option = option
                        editingActivity = current
                    }
                    Button(store.weeklyPlan.reminders.contains(where: { $0.weekday == selectedWeekday && $0.activityID == activity.id })
                           ? "Edit reminder" : "Add reminder", systemImage: "bell.badge") {
                        reminderSelection = WeeklyReminderSelection(activityID: activity.id, weekday: selectedWeekday)
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.deleteWeeklyActivity(id: activity.id, on: selectedWeekday)
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Options for \(store.displayLabel(for: item))")
        }
        .padding(.vertical, 3)
        .background(activity.id == highlightedActivityID ? Color.yellow.opacity(0.18) : Color.clear)
        .accessibilityIdentifier("weekly-activity-\(activity.id.uuidString)")
    }

    private func dayName(_ weekday: Int?) -> String {
        guard let weekday, (1...7).contains(weekday) else { return "day" }
        return Calendar.current.weekdaySymbols[weekday - 1]
    }
}

private struct WeeklyReminderSelection: Identifiable {
    let activityID: UUID
    let weekday: Int
    var id: UUID { activityID }
}

private struct WeekDayButton: View {
    let date: Date
    let weekday: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text(date.formatted(.dateTime.day()))
                    .font(.title2.bold())
            }
            .frame(minWidth: 54, minHeight: 58)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .indigo : .gray)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("weekly-day-\(weekday)")
    }
}
