import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminderNavigation = RoutineReminderNavigation.shared
    @State private var selectedTab = 0
    @State private var hasBeenActive = false
    @State private var isTyping = false
    @State private var remindedTemplate: RoutineTemplate?
    @State private var remindedWeeklyTarget: WeeklyReminderTarget?
    @State private var remindedCalendarTarget: CalendarReminderTarget?
    @State private var reminderError: String?

    var body: some View {
        VStack(spacing: 0) {
            if store.settings.showUrgentBar { UrgentCommunicationBar() }
            if store.isBoardOnlyModeActive {
                SpeakView(isTyping: $isTyping, homeBoard: store.homeBoard)
            } else {
                VStack(spacing: 0) {
                    if selectedTab != 0 { QuickResponseBar() }
                    TabView(selection: $selectedTab) {
                        SpeakView(isTyping: $isTyping, homeBoard: store.homeBoard)
                            .tabItem { Label("Speak", systemImage: "quote.bubble.fill") }
                            .tag(0)
                        PhrasesView(openKeyboard: {
                            isTyping = true
                            selectedTab = 0
                        })
                            .tabItem { Label("Phrases", systemImage: "text.bubble.fill") }
                            .tag(1)
                        RoutineView(onOpenSpeak: { selectedTab = 0 })
                            .tabItem { Label("Routine", systemImage: "checklist") }
                            .tag(2)
                        StoriesView()
                            .tabItem { Label("Stories", systemImage: "books.vertical.fill") }
                            .tag(3)
                        SettingsView()
                            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                            .tag(4)
                    }
                }
            }
        }
        .tint(store.settings.highContrast ? .black : .indigo)
        .onAppear {
            if scenePhase == .active { hasBeenActive = true }
            openReminderTarget()
            openWeeklyReminderTarget()
            openCalendarReminderTarget()
        }
        .onChange(of: store.isBoardOnlyModeActive) { _, active in
            if !active { selectedTab = 0 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasBeenActive = true
            } else if hasBeenActive {
                store.flushConversationDraft()
                store.flushPersistence()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await store.restoreAllReminders()
            openReminderTarget()
            openWeeklyReminderTarget()
            openCalendarReminderTarget()
        }
        .onChange(of: reminderNavigation.target) { _, _ in openReminderTarget() }
        .onChange(of: reminderNavigation.weeklyTarget) { _, _ in openWeeklyReminderTarget() }
        .onChange(of: reminderNavigation.calendarTarget) { _, _ in openCalendarReminderTarget() }
        .sheet(item: $remindedTemplate) { template in
            NavigationStack {
                RoutineTemplateBoardView(template: template, onOpenSpeak: {
                    remindedTemplate = nil
                    selectedTab = 0
                })
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { remindedTemplate = nil }
                        }
                    }
            }
        }
        .sheet(item: $remindedWeeklyTarget) { target in
            NavigationStack {
                WeeklyPlanView(initialWeekday: target.weekday, highlightedActivityID: target.activityID)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { remindedWeeklyTarget = nil }
                        }
                    }
            }
        }
        .sheet(item: $remindedCalendarTarget) { target in
            NavigationStack {
                VisualCalendarView(initialDate: target.date, highlightedEventID: target.eventID)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { remindedCalendarTarget = nil }
                        }
                    }
            }
        }
        .alert("Could not open reminder", isPresented: Binding(
            get: { reminderError != nil },
            set: { if !$0 { reminderError = nil } }
        )) {
            Button("OK") { reminderError = nil }
        } message: {
            Text(reminderError ?? "")
        }
    }

    private func openReminderTarget() {
        guard let target = reminderNavigation.target else { return }
        reminderNavigation.target = nil
        guard store.profiles.contains(where: { $0.id == target.profileID }) else {
            reminderError = "The profile for this reminder is no longer available."
            return
        }
        guard target.profileID == store.activeProfileID || store.switchProfile(to: target.profileID) else {
            reminderError = "Leave board-only mode to open the routine for this profile."
            return
        }
        guard let template = store.routineTemplates.first(where: { $0.id == target.templateID }) else {
            reminderError = "The saved routine is no longer available."
            return
        }
        remindedTemplate = template
    }

    private func openWeeklyReminderTarget() {
        guard let target = reminderNavigation.weeklyTarget else { return }
        reminderNavigation.weeklyTarget = nil
        guard store.profiles.contains(where: { $0.id == target.profileID }) else {
            reminderError = "The profile for this reminder is no longer available."
            return
        }
        guard target.profileID == store.activeProfileID || store.switchProfile(to: target.profileID) else {
            reminderError = "Leave board-only mode to open the plan for this profile."
            return
        }
        guard (1...7).contains(target.weekday),
              store.weeklyPlan.activities(on: target.weekday).contains(where: { $0.id == target.activityID }) else {
            reminderError = "The planned activity is no longer available."
            return
        }
        remindedWeeklyTarget = target
    }

    private func openCalendarReminderTarget() {
        guard let target = reminderNavigation.calendarTarget else { return }
        reminderNavigation.calendarTarget = nil
        guard store.profiles.contains(where: { $0.id == target.profileID }) else {
            reminderError = "The profile for this reminder is no longer available."
            return
        }
        guard target.profileID == store.activeProfileID || store.switchProfile(to: target.profileID) else {
            reminderError = "Leave board-only mode to open the calendar for this profile."
            return
        }
        guard store.visualCalendar.events.contains(where: { $0.id == target.eventID }) else {
            reminderError = "The calendar event is no longer available."
            return
        }
        remindedCalendarTarget = target
    }
}

private struct UrgentCommunicationBar: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showingBedside = false
    @State private var lastActivation = Date.distantPast

    private var language: String { store.settings.communicationLanguage }
    private var primaryCard: BedsideCard {
        store.settings.cardsForBedside(language: language).first
            ?? BedsideCard.starterCards(language: language)[0]
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                let now = Date()
                guard now.timeIntervalSince(lastActivation) >= 0.35 else { return }
                lastActivation = now
                store.speakStandaloneMessage(primaryCard.message)
            } label: {
                HStack(spacing: 8) {
                    Text(primaryCard.symbol)
                        .accessibilityHidden(true)
                    Text(primaryCard.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "speaker.wave.2.fill")
                        .accessibilityHidden(true)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.settings.highContrast ? .black : .red)
            .accessibilityLabel("Speak \(primaryCard.message)")
            .accessibilityHint("Speaks immediately without changing your message")
            .accessibilityIdentifier("urgent-bar-speak")

            Button(language == "es" ? "Más" : "More", systemImage: "square.grid.2x2") {
                showingBedside = true
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(language == "es" ? "Más mensajes urgentes" : "More urgent messages")
            .accessibilityIdentifier("urgent-bar-more")
        }
        .controlSize(.large)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(store.settings.highContrast ? Color.white : Color.red.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
        .sheet(isPresented: $showingBedside) { BedsideView().environmentObject(store) }
    }
}
