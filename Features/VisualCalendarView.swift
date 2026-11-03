import PhotosUI
import SwiftUI

private enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case month, week, day

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct VisualCalendarView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var displayMode: CalendarDisplayMode = .month
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var today = Date()
    @State private var showingNewEvent = false
    @State private var showingAppearance = false
    @State private var showingEditProtection = false
    @State private var showingWordPicker = false
    @State private var editingEvent: CalendarEvent?
    @State private var reminderEvent: CalendarEvent?
    @State private var calendarPDF: PDFPreviewPayload?
    private let highlightedEventID: UUID?

    init(initialDate: Date? = nil, highlightedEventID: UUID? = nil) {
        let date = Calendar.current.startOfDay(for: initialDate ?? Date())
        _selectedDate = State(initialValue: date)
        _displayedMonth = State(initialValue: date)
        _displayMode = State(initialValue: highlightedEventID == nil ? .month : .day)
        self.highlightedEventID = highlightedEventID
    }

    private var calendar: Calendar { .current }

    private var weekDays: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
            return [selectedDate]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let range = calendar.range(of: .day, in: .month, for: interval.start) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let dates = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        return Array<Date?>(repeating: nil, count: leading) + dates.map(Optional.some)
    }

    private var countdowns: [CalendarCountdown] {
        store.visualCalendar.events.compactMap { event in
            guard event.showsCountdown,
                  let days = event.daysUntilNext(from: today, calendar: calendar) else { return nil }
            return CalendarCountdown(event: event, days: days)
        }.sorted { $0.days < $1.days }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Calendar view", selection: $displayMode) {
                        ForEach(CalendarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("calendar-display-mode")
                    switch displayMode {
                    case .month:
                        monthNavigation
                        monthGrid
                        if !countdowns.isEmpty { countdownSection }
                        daySection(on: selectedDate, compactEmpty: false)
                    case .week:
                        weekNavigation
                        ForEach(weekDays, id: \.self) { date in
                            daySection(on: date, compactEmpty: true)
                        }
                        NavigationLink("Open repeating weekly plan", destination: WeeklyPlanView())
                    case .day:
                        dayNavigation
                        daySection(on: selectedDate, compactEmpty: false)
                    }
                }
                .padding()
                .frame(maxWidth: 840)
                .frame(maxWidth: .infinity)
            }
            .task {
                if let highlightedEventID {
                    await Task.yield()
                    proxy.scrollTo(highlightedEventID, anchor: .center)
                }
            }
        }
        .navigationTitle("Visual calendar")
        .toolbar {
            Menu {
                Button(store.visualCalendar.isEditingLocked ?
                       (store.calendarEditingBlocked ? "Unlock calendar editing" : "Calendar edit protection") :
                       "Protect calendar editing",
                       systemImage: store.visualCalendar.isEditingLocked ?
                       (store.calendarEditingBlocked ? "lock.fill" : "lock.open") : "lock.open") {
                    showingEditProtection = true
                }
                .accessibilityIdentifier("calendar-edit-protection-open")
                Button("Calendar appearance", systemImage: "paintpalette") { showingAppearance = true }
                    .disabled(store.calendarEditingBlocked)
                    .accessibilityIdentifier("calendar-appearance-open")
            } label: {
                Label("Calendar settings", systemImage: store.calendarEditingBlocked ? "lock.fill" : "gearshape")
            }
            .accessibilityIdentifier("calendar-settings-menu")
            Menu {
                ForEach(CalendarPDFRange.allCases) { range in
                    Button(range.title) { makePDF(range: range) }
                }
            } label: {
                Label("Printable calendar PDF", systemImage: "printer")
            }
            .accessibilityIdentifier("calendar-print-menu")
            Button("Add event", systemImage: "plus") { showingNewEvent = true }
                .disabled(store.calendarEditingBlocked)
                .accessibilityIdentifier("calendar-add-event")
        }
        .sheet(isPresented: $showingEditProtection) {
            CalendarEditProtectionView()
        }
        .sheet(isPresented: $showingNewEvent) {
            CalendarEventEditorView(event: nil, selectedDate: selectedDate)
        }
        .sheet(isPresented: $showingAppearance) {
            CalendarAppearanceEditorView(appearance: store.visualCalendar.effectiveAppearance)
        }
        .sheet(item: $editingEvent) { event in
            CalendarEventEditorView(event: event, selectedDate: selectedDate)
        }
        .sheet(item: $reminderEvent) { event in
            CalendarEventReminderView(eventID: event.id)
        }
        .sheet(item: $calendarPDF) { payload in
            PrintableBoardsPreview(data: payload.data, title: "Calendar PDF",
                                   filename: "Open Voice Calendar")
        }
        .sheet(isPresented: $showingWordPicker) {
            SceneWordPickerView { item in
                let event = CalendarEvent(option: ChoiceOption(item: item), startDate: selectedDate)
                _ = store.addCalendarEvent(event)
            }
        }
        .onChange(of: store.activeProfileID) { _, _ in
            selectedDate = calendar.startOfDay(for: Date())
            displayedMonth = selectedDate
            displayMode = .month
            showingNewEvent = false
            showingAppearance = false
            showingEditProtection = false
            editingEvent = nil
            reminderEvent = nil
            calendarPDF = nil
        }
        .onChange(of: displayMode) { _, newMode in
            if newMode == .month { displayedMonth = selectedDate }
        }
        .onChange(of: store.calendarEditingBlocked) { _, blocked in
            if blocked {
                showingNewEvent = false
                showingAppearance = false
                showingWordPicker = false
                editingEvent = nil
                reminderEvent = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.lockCalendarEditing() }
        }
        .onDisappear { store.lockCalendarEditing() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            today = Date()
        }
    }

    private func makePDF(range: CalendarPDFRange) {
        let date = range == .month ? displayedMonth : selectedDate
        calendarPDF = PDFPreviewPayload(data: PrintableCalendarPDF.makeData(
            profileName: store.activeProfileName, date: date, range: range,
            visualCalendar: store.visualCalendar, weeklyPlan: store.weeklyPlan,
            items: store.items, language: store.settings.communicationLanguage))
    }

    private var monthNavigation: some View {
        HStack {
            Button("Previous month", systemImage: "chevron.left") { moveMonth(-1) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .accessibilityIdentifier("calendar-month-title")
            Spacer()
            Button("Next month", systemImage: "chevron.right") { moveMonth(1) }
                .labelStyle(.iconOnly)
            Button("Today") { selectToday() }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("calendar-today")
        }
    }

    private var weekNavigation: some View {
        HStack {
            Button("Previous week", systemImage: "chevron.left") { moveSelectedDate(by: -7) }
                .labelStyle(.iconOnly)
            Spacer()
            if let first = weekDays.first, let last = weekDays.last {
                Text("\(first.formatted(.dateTime.month(.abbreviated).day())) – " +
                     last.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.title2.bold())
                    .accessibilityIdentifier("calendar-week-title")
            }
            Spacer()
            Button("Next week", systemImage: "chevron.right") { moveSelectedDate(by: 7) }
                .labelStyle(.iconOnly)
            Button("Today") { selectToday() }
                .buttonStyle(.bordered)
        }
    }

    private var dayNavigation: some View {
        HStack {
            Button("Previous day", systemImage: "chevron.left") { moveSelectedDate(by: -1) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.title2.bold())
                .accessibilityIdentifier("calendar-day-title")
            Spacer()
            Button("Next day", systemImage: "chevron.right") { moveSelectedDate(by: 1) }
                .labelStyle(.iconOnly)
            Button("Today") { selectToday() }
                .buttonStyle(.bordered)
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        return VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { offset in
                    let weekday = (calendar.firstWeekday - 1 + offset) % 7
                    Text(calendar.veryShortStandaloneWeekdaySymbols[weekday])
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(0..<monthDays.count, id: \.self) { index in
                    if let date = monthDays[index] {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 70)
                    }
                }
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let events = store.visualCalendar.events(on: date)
        let weekly = store.weeklyPlan.activities(on: calendar.component(.weekday, from: date))
        let count = events.count + weekly.count
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let eventColor = store.settings.highContrast ? nil : events.compactMap { $0.colorHex }.first.flatMap { ButtonColorValue(text: $0) }
        let tint = eventColor.map(ButtonColorAppearance.color)
        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: store.visualCalendar.effectiveAppearance.dayNumberSize.pointSize, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(events.first?.option.symbol ?? weekly.first?.option.symbol ?? " ")
                    .font(.title3)
                    .lineLimit(1)
                if count > 0 {
                    Text("\(count) event\(count == 1 ? "" : "s")")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? Color.indigo : (tint?.opacity(0.2) ?? (isToday ? Color.indigo.opacity(0.15) : Color.gray.opacity(0.08))),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if let tint, !isSelected {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(tint, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(count) events")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Count days until").font(.title3.bold())
            ForEach(countdowns) { entry in
                HStack(spacing: 12) {
                    Text(entry.event.option.symbol).font(.title)
                    Text(entry.event.option.label).font(.headline)
                    Spacer()
                    Text(entry.days == 0 ? "Today" : "\(entry.days) day\(entry.days == 1 ? "" : "s")")
                        .font(.headline.monospacedDigit())
                }
                .padding(12)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func daySection(on date: Date, compactEmpty: Bool) -> some View {
        let events = store.visualCalendar.events(on: date)
        let activities = store.weeklyPlan.activities(on: calendar.component(.weekday, from: date))
        let pendingEvents = events.filter { !$0.isComplete(on: date) }
        let finishedEvents = events.filter { $0.isComplete(on: date) }
        let pendingActivities = activities.filter { !$0.isComplete(on: date) }
        let finishedActivities = activities.filter { $0.isComplete(on: date) }
        let appearance = store.visualCalendar.effectiveAppearance
        return VStack(alignment: .leading, spacing: 10) {
            if displayMode != .day {
                if displayMode == .week {
                    Button(date.formatted(.dateTime.weekday(.wide).month(.wide).day())) {
                        selectedDate = date
                        displayMode = .day
                    }
                    .font(.title3.bold())
                    .accessibilityIdentifier("calendar-open-day-\(calendar.component(.weekday, from: date))")
                } else {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title3.bold())
                }
            }
            if events.isEmpty && activities.isEmpty {
                if compactEmpty {
                    Text("Nothing planned").foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Nothing planned", systemImage: "calendar",
                                           description: Text("Add an event or use the repeating weekly plan."))
                }
            }
            if !pendingEvents.isEmpty || !pendingActivities.isEmpty {
                if appearance.showsLabel(forCompleted: false) {
                    sectionHeading(appearance.title(forCompleted: false, language: store.settings.communicationLanguage),
                                   audioData: appearance.audioData(forCompleted: false))
                }
                ForEach(pendingEvents) { event in eventRow(event, on: date).id(event.id) }
                ForEach(pendingActivities) { activity in weeklyRow(activity, on: date) }
            }
            if !finishedEvents.isEmpty || !finishedActivities.isEmpty {
                if appearance.showsLabel(forCompleted: true) {
                    sectionHeading(appearance.title(forCompleted: true, language: store.settings.communicationLanguage),
                                   audioData: appearance.audioData(forCompleted: true))
                }
                ForEach(finishedEvents) { event in eventRow(event, on: date).id(event.id) }
                ForEach(finishedActivities) { activity in weeklyRow(activity, on: date) }
            }
            Button("Add an event", systemImage: "plus") {
                selectedDate = date
                showingNewEvent = true
            }
                .disabled(store.calendarEditingBlocked)
                .accessibilityIdentifier("calendar-add-on-day")
            if displayMode != .week {
                Button("Add from my words", systemImage: "text.bubble") { showingWordPicker = true }
                    .disabled(store.calendarEditingBlocked)
                NavigationLink("Open repeating weekly plan", destination: WeeklyPlanView())
            }
        }
    }

    private func sectionHeading(_ title: String, audioData: Data?) -> some View {
        Button(title) {
            if let audioData { store.playRecorded(audioData) }
            else { store.speak(title) }
        }
            .font(.headline)
            .buttonStyle(.plain)
            .accessibilityHint("Speak section name")
    }

    private func eventRow(_ event: CalendarEvent, on date: Date) -> some View {
        let option = event.option.resolved(using: store.items)
        let done = event.isComplete(on: date)
        let rewardChart = store.rewardCharts.first(where: { $0.id == event.rewardChartID })
        let eventColor = store.settings.highContrast ? nil : event.colorHex.flatMap { ButtonColorValue(text: $0) }
        return HStack(spacing: 12) {
            eventPicture(option)
            Button {
                speak(option)
            } label: {
                VStack(alignment: .leading) {
                    Text(option.label).font(.headline)
                    Text(event.repeatRule.title).font(.caption).foregroundStyle(.secondary)
                    if let rewardChart {
                        Label(rewardChart.title, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Say \(option.label)")
            if event.reminder != nil {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.indigo)
                    .accessibilityLabel("Reminder set")
            }
            Button(done ? "Mark not done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "circle") {
                store.toggleCalendarEvent(id: event.id, on: date)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel(done ? "Mark not done for \(option.label)" : "Mark done for \(option.label)")
            .accessibilityIdentifier("calendar-toggle-\(event.id.uuidString)")
            Menu {
                if store.calendarEditingBlocked {
                    Button("Unlock editing", systemImage: "lock.open") { showingEditProtection = true }
                } else {
                    Button("Edit event", systemImage: "pencil") { editingEvent = event }
                    Button(event.reminder == nil ? "Add reminder" : "Edit reminder", systemImage: "bell.badge") {
                        reminderEvent = event
                    }
                    Button("Delete event", systemImage: "trash", role: .destructive) {
                        store.deleteCalendarEvent(id: event.id)
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Options for \(option.label)")
        }
        .padding(10)
        .background(event.id == highlightedEventID ? Color.yellow.opacity(0.2) :
                    (eventColor.map { ButtonColorAppearance.color($0).opacity(0.18) } ?? Color.gray.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("calendar-event-\(event.id.uuidString)")
    }

    private func weeklyRow(_ activity: WeeklyActivity, on date: Date) -> some View {
        let option = activity.option.resolved(using: store.items)
        let done = activity.isComplete(on: date)
        let weekday = calendar.component(.weekday, from: date)
        let rewardChart = store.rewardCharts.first(where: { $0.id == activity.rewardChartID })
        return HStack(spacing: 12) {
            eventPicture(option)
            Button { speak(option) } label: {
                VStack(alignment: .leading) {
                    Text(option.label).font(.headline)
                    Text("Weekly plan").font(.caption).foregroundStyle(.secondary)
                    if let rewardChart {
                        Label(rewardChart.title, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Say \(option.label)")
            Button(done ? "Mark not done" : "Mark done",
                   systemImage: done ? "checkmark.circle.fill" : "circle") {
                store.toggleWeeklyActivity(id: activity.id, on: weekday, date: date)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel(done ? "Mark not done for \(option.label)" : "Mark done for \(option.label)")
        }
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func eventPicture(_ option: ChoiceOption) -> some View {
        if let data = option.imageData {
            AsyncThumbnailImage(data: data) {
                Text(option.symbol).font(.title)
            }
                .frame(width: 48, height: 48).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        } else {
            Text(option.symbol).font(.title)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
    }

    private func speak(_ option: ChoiceOption) {
        let item = option.communicationItem
        store.select(item)
        if item.audioData == nil && !store.settings.speakOnTap {
            store.speak(store.displayMessage(for: item))
        }
    }

    private func moveMonth(_ amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = calendar.dateInterval(of: .month, for: next)?.start ?? next
    }

    private func moveSelectedDate(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = calendar.startOfDay(for: next)
        displayedMonth = selectedDate
    }

    private func selectToday() {
        selectedDate = calendar.startOfDay(for: today)
        displayedMonth = selectedDate
    }
}

private struct CalendarCountdown: Identifiable {
    let event: CalendarEvent
    let days: Int
    var id: UUID { event.id }
}

struct CalendarEditProtectionView: View {
    private enum PINField: Hashable { case new, confirmation, unlock }
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: PINField?
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if !store.visualCalendar.isEditingLocked {
                    Section("Set a calendar PIN") {
                        SecureField("4 to 8 numbers", text: $pin)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .new)
                            .accessibilityIdentifier("calendar-lock-new-pin")
                        SecureField("Confirm PIN", text: $confirmation)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .confirmation)
                            .accessibilityIdentifier("calendar-lock-confirm-pin")
                        Button("Protect editing") {
                            guard pin == confirmation else {
                                errorMessage = "The PINs do not match."
                                return
                            }
                            do {
                                try store.enableCalendarEditingLock(pin: pin)
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                        .disabled(!BoardOnlyPINStore.isValid(pin) || confirmation.isEmpty)
                        .accessibilityIdentifier("calendar-lock-enable")
                    }
                    Section {
                        Text("A PIN protects calendar events, weekly-plan activities, reminders, and appearance changes. Speaking and marking activities done stay available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if store.calendarEditingBlocked {
                    Section("Unlock editing") {
                        SecureField("Calendar PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .unlock)
                            .accessibilityIdentifier("calendar-lock-pin")
                        Button("Unlock editing") {
                            if store.unlockCalendarEditing(pin: pin) { dismiss() }
                            else { errorMessage = "That PIN did not match. Try again." }
                        }
                        .disabled(pin.isEmpty)
                        .accessibilityIdentifier("calendar-lock-unlock")
                    }
                    Section {
                        Text("Speaking, viewing, printing, and marking activities done remain available while editing is locked.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Editing is unlocked") {
                        Button("Lock editing now", systemImage: "lock.fill") {
                            store.lockCalendarEditing()
                            dismiss()
                        }
                        .accessibilityIdentifier("calendar-lock-now")
                        Button("Turn off edit protection", role: .destructive) {
                            if store.disableCalendarEditingLock() { dismiss() }
                        }
                        .accessibilityIdentifier("calendar-lock-disable")
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Calendar edit protection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done editing") { focusedField = nil }
                        .accessibilityIdentifier("calendar-lock-done-editing")
                }
            }
        }
    }
}

private struct CalendarAppearanceEditorView: View {
    private enum LabelVoice { case planned, completed }
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var dayNumberSize: CalendarDayNumberSize
    @State private var plannedLabel: String
    @State private var completedLabel: String
    @State private var showsPlannedLabel: Bool
    @State private var showsCompletedLabel: Bool
    @State private var plannedAudioData: Data?
    @State private var completedAudioData: Data?
    @State private var recordingTarget: LabelVoice?
    @State private var recordingError: String?
    @State private var isPreparingRecording = false
    @StateObject private var recorder = AudioMessageRecorder()
    @FocusState private var editingLabel: Bool

    init(appearance: CalendarAppearance) {
        _dayNumberSize = State(initialValue: appearance.dayNumberSize)
        _plannedLabel = State(initialValue: appearance.plannedLabel ?? "")
        _completedLabel = State(initialValue: appearance.completedLabel ?? "")
        _showsPlannedLabel = State(initialValue: appearance.showsLabel(forCompleted: false))
        _showsCompletedLabel = State(initialValue: appearance.showsLabel(forCompleted: true))
        _plannedAudioData = State(initialValue: appearance.plannedAudioData)
        _completedAudioData = State(initialValue: appearance.completedAudioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Day numbers") {
                    Picker("Day number size", selection: $dayNumberSize) {
                        ForEach(CalendarDayNumberSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .accessibilityIdentifier("calendar-day-number-size")
                    Text("31")
                        .font(.system(size: dayNumberSize.pointSize, weight: .bold))
                        .accessibilityLabel("Day number preview: 31")
                }
                Section("Day sections") {
                    TextField("To do", text: $plannedLabel)
                        .focused($editingLabel)
                        .disabled(recorder.isRecording || isPreparingRecording)
                        .accessibilityIdentifier("calendar-planned-label")
                        .onChange(of: plannedLabel) { _, _ in plannedAudioData = nil }
                    TextField("Finished", text: $completedLabel)
                        .focused($editingLabel)
                        .disabled(recorder.isRecording || isPreparingRecording)
                        .accessibilityIdentifier("calendar-completed-label")
                        .onChange(of: completedLabel) { _, _ in completedAudioData = nil }
                    Toggle("Show planned heading", isOn: $showsPlannedLabel)
                        .accessibilityIdentifier("calendar-show-planned-label")
                    Toggle("Show finished heading", isOn: $showsCompletedLabel)
                        .accessibilityIdentifier("calendar-show-completed-label")
                    Text("Leave a label empty to use the default for your communication language.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Planned label voice") {
                    Button(recorder.isRecording && recordingTarget == .planned ?
                           "Stop planned recording" : "Record planned label",
                           systemImage: recorder.isRecording && recordingTarget == .planned ? "stop.fill" : "mic.fill") {
                        toggleRecording(for: .planned)
                    }
                    .disabled(plannedLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isPreparingRecording ||
                              (recorder.isRecording && recordingTarget != .planned))
                    .accessibilityIdentifier("calendar-record-planned-label")
                    if let plannedAudioData {
                        Button("Play planned recording", systemImage: "play.fill") {
                            store.playRecorded(plannedAudioData)
                        }
                        .disabled(recorder.isRecording)
                        Button("Remove planned recording", role: .destructive) { self.plannedAudioData = nil }
                            .disabled(recorder.isRecording)
                    }
                }
                Section("Finished label voice") {
                    Button(recorder.isRecording && recordingTarget == .completed ?
                           "Stop finished recording" : "Record finished label",
                           systemImage: recorder.isRecording && recordingTarget == .completed ? "stop.fill" : "mic.fill") {
                        toggleRecording(for: .completed)
                    }
                    .disabled(completedLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isPreparingRecording ||
                              (recorder.isRecording && recordingTarget != .completed))
                    .accessibilityIdentifier("calendar-record-completed-label")
                    if let completedAudioData {
                        Button("Play finished recording", systemImage: "play.fill") {
                            store.playRecorded(completedAudioData)
                        }
                        .disabled(recorder.isRecording)
                        Button("Remove finished recording", role: .destructive) { self.completedAudioData = nil }
                            .disabled(recorder.isRecording)
                    }
                }
                if let error = recordingError ?? recorder.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
                if isPreparingRecording { ProgressView("Preparing microphone") }
            }
            .navigationTitle("Calendar appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setCalendarAppearance(CalendarAppearance(
                            dayNumberSize: dayNumberSize,
                            plannedLabel: plannedLabel,
                            completedLabel: completedLabel,
                            showsPlannedLabel: showsPlannedLabel,
                            showsCompletedLabel: showsCompletedLabel,
                            plannedAudioData: plannedAudioData,
                            completedAudioData: completedAudioData))
                        dismiss()
                    }
                    .disabled(recorder.isRecording || isPreparingRecording)
                    .accessibilityIdentifier("calendar-appearance-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done editing") { editingLabel = false }
                        .accessibilityIdentifier("calendar-appearance-done-editing")
                }
            }
            .onDisappear { recorder.discard() }
        }
    }

    private func toggleRecording(for target: LabelVoice) {
        if recorder.isRecording {
            let data = recorder.stop()
            if target == .planned { plannedAudioData = data }
            else { completedAudioData = data }
            if data == nil { recordingError = "The recording could not be saved. Try again." }
            recordingTarget = nil
        } else {
            recordingError = nil
            recordingTarget = target
            isPreparingRecording = true
            Task {
                await recorder.start()
                isPreparingRecording = false
                if !recorder.isRecording { recordingTarget = nil }
            }
        }
    }
}

private struct CalendarEventEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent?
    @State private var title: String
    @State private var message: String
    @State private var symbol: String
    @State private var date: Date
    @State private var repeatRule: CalendarRepeatRule
    @State private var showsCountdown: Bool
    @State private var imageData: Data?
    @State private var audioData: Data?
    @State private var hasCustomColor: Bool
    @State private var color: Color
    @State private var rewardChartID: UUID?
    @State private var selectedPhoto: PhotosPickerItem?
    @StateObject private var recorder = AudioMessageRecorder()
    @State private var saveError = false
    @FocusState private var editingText: Bool

    init(event: CalendarEvent?, selectedDate: Date) {
        self.event = event
        _title = State(initialValue: event?.option.label ?? "")
        _message = State(initialValue: event?.option.message ?? "")
        _symbol = State(initialValue: event?.option.symbol ?? "⭐️")
        _date = State(initialValue: event?.startDate ?? selectedDate)
        _repeatRule = State(initialValue: event?.repeatRule ?? .never)
        _showsCountdown = State(initialValue: event?.showsCountdown ?? false)
        _imageData = State(initialValue: event?.option.imageData)
        _audioData = State(initialValue: event?.option.audioData)
        let savedColor = event?.colorHex.flatMap { ButtonColorValue(text: $0) }
        _hasCustomColor = State(initialValue: savedColor != nil)
        _color = State(initialValue: savedColor.map(ButtonColorAppearance.color) ?? .indigo)
        _rewardChartID = State(initialValue: event?.rewardChartID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Event name", text: $title)
                        .focused($editingText)
                        .accessibilityIdentifier("calendar-event-title")
                    TextField("What should it say?", text: $message)
                        .focused($editingText)
                    TextField("Emoji or symbol", text: $symbol)
                        .focused($editingText)
                    DatePicker("First date", selection: $date, displayedComponents: .date)
                        .accessibilityIdentifier("calendar-event-date")
                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(CalendarRepeatRule.allCases) { rule in
                            Text(rule.title).tag(rule)
                        }
                    }
                    .accessibilityIdentifier("calendar-repeat")
                    Button {
                        showsCountdown.toggle()
                    } label: {
                        HStack {
                            Text("Show days until this event")
                            Spacer()
                            Image(systemName: showsCountdown ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(showsCountdown ? .indigo : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar-countdown")
                        .accessibilityValue(showsCountdown ? "On" : "Off")
                }
                Section("Color") {
                    Toggle("Custom event color", isOn: $hasCustomColor)
                        .accessibilityIdentifier("calendar-custom-color")
                    if hasCustomColor {
                        ColorPicker("Event color", selection: $color, supportsOpacity: false)
                            .accessibilityIdentifier("calendar-event-color")
                    }
                }
                Section("Reward chart") {
                    Menu {
                        Button("No linked chart") { rewardChartID = nil }
                        ForEach(store.rewardCharts) { chart in
                            Button(chart.title) { rewardChartID = chart.id }
                        }
                    } label: {
                        HStack {
                            Text("Award a token on completion")
                            Spacer()
                            Text(store.rewardCharts.first(where: { $0.id == rewardChartID })?.title ?? "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("calendar-event-reward-chart")
                    Text("A completed occurrence earns one token while the chart has space. Rechecking the same date does not earn another.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Picture") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose a photo", systemImage: "photo")
                    }
                    PictureLibraryPickerButton(title: "Picture library",
                                               identifier: "calendar-event-picture-library") { picture in
                        imageData = picture.imageData
                    }
                    CameraPhotoButton { imageData = $0 }
                    if let imageData {
                        AsyncThumbnailImage(data: imageData, contentMode: .fit) {
                            Image(systemName: "photo")
                        }
                        .frame(maxHeight: 180)
                        Button("Remove photo", role: .destructive) { self.imageData = nil }
                    }
                }
                Section("Voice") {
                    Button(recorder.isRecording ? "Stop recording" : "Record a voice",
                           systemImage: recorder.isRecording ? "stop.fill" : "mic.fill") {
                        if recorder.isRecording { audioData = recorder.stop() }
                        else { Task { await recorder.start() } }
                    }
                    if let audioData {
                        Button("Play recording", systemImage: "play.fill") { store.playRecorded(audioData) }
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                    }
                    if let error = recorder.errorMessage { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(event == nil ? "New event" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recorder.isRecording)
                        .accessibilityIdentifier("calendar-save-event")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done editing") { editingText = false }
                        .accessibilityIdentifier("calendar-done-editing")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = await PhotoProcessing.preparedDataAsync(from: data)
                    }
                }
            }
            .onDisappear { recorder.discard() }
            .alert("Could not save event", isPresented: $saveError) {
                Button("OK") {}
            } message: {
                Text("Give the event a name and spoken message.")
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let option = ChoiceOption(label: cleanTitle, symbol: symbol.isEmpty ? "⭐️" : symbol,
                                  message: cleanMessage.isEmpty ? cleanTitle : cleanMessage,
                                  imageData: imageData, audioData: audioData)
        let updated = CalendarEvent(id: event?.id ?? UUID(), option: option,
                                    startDate: Calendar.current.startOfDay(for: date),
                                    repeatRule: repeatRule, showsCountdown: showsCountdown,
                                    completedOn: event?.completedOn ?? [], reminder: event?.reminder,
                                    colorHex: hasCustomColor ? ButtonColorAppearance.hex(from: color) : nil,
                                    rewardChartID: rewardChartID)
        let saved = event == nil ? store.addCalendarEvent(updated) : store.updateCalendarEvent(updated)
        if saved { dismiss() } else { saveError = true }
    }
}
