import Combine
import SwiftUI

struct RoutineView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    let onOpenSpeak: () -> Void
    @State private var newStep = ""
    @State private var newSymbol = "⭐️"
    @State private var newDuration = 0
    @State private var timerPath: [UUID] = []
    @State private var showingNewStepEditor = false
    @State private var editingStep: RoutineStep?
    @State private var playingVideoStep: RoutineStep?
    @State private var activeChoiceBoard: ChoiceBoard?
    @State private var routinePDF: PDFPreviewPayload?
    @State private var showingRecordSaved = false
    @State private var waitDuration = 180
    @State private var waitClock = RoutineStepClock(durationSeconds: 180)
    @State private var waitNow = Date()
    @State private var showingFullScreenWait = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(onOpenSpeak: @escaping () -> Void) {
        self.onOpenSpeak = onOpenSpeak
    }

    private var remainingSteps: [RoutineStep] { store.routines.filter { !$0.isComplete } }
    private var waitRemaining: Int { waitClock.secondsRemaining(at: waitNow) }
    private var waitActionTitle: String {
        if waitClock.isRunning { return "Pause" }
        if waitRemaining == 0 { return "Start again" }
        return waitRemaining == waitDuration ? "Start" : "Resume"
    }

    var body: some View {
        NavigationStack(path: $timerPath) {
            List {
                Section("Calm and communicate") {
                    NavigationLink {
                        CalmSpaceView(onOpenSpeak: onOpenSpeak)
                    } label: {
                        Label("Calm space", systemImage: "moon.stars")
                    }
                    .accessibilityIdentifier("open-calm-space")
                }
                Section("Plan and print") {
                    NavigationLink {
                        VisualCalendarView()
                    } label: {
                        Label("Visual calendar", systemImage: "calendar.badge.clock")
                    }
                    .accessibilityIdentifier("open-visual-calendar")
                    NavigationLink {
                        WeeklyPlanView()
                    } label: {
                        Label("Weekly plan", systemImage: "calendar")
                    }
                    .accessibilityIdentifier("open-weekly-plan")
                    NavigationLink {
                        RoutineTemplatesView(onOpenSpeak: onOpenSpeak)
                    } label: {
                        Label("Saved routines", systemImage: "square.stack")
                    }
                    .accessibilityIdentifier("open-routine-templates")
                    NavigationLink {
                        RewardChartsView()
                    } label: {
                        Label("Reward charts", systemImage: "star.circle")
                    }
                    .accessibilityIdentifier("open-reward-charts")
                    Button("Printable routine PDF", systemImage: "doc.richtext") {
                        routinePDF = PDFPreviewPayload(data: PrintableRoutinePDF.makeData(
                            profileName: store.activeProfileName, steps: store.routines,
                            language: store.settings.communicationLanguage))
                    }
                    .disabled(store.routines.isEmpty)
                    .accessibilityIdentifier("open-routine-pdf")
                }
                Section {
                    Text("See what is next, and mark each step when it is done.")
                        .foregroundStyle(.secondary)
                    if !store.routines.isEmpty {
                        let done = store.routines.filter(\.isComplete).count
                        Text("\(done) of \(store.routines.count) steps done")
                            .font(.subheadline.weight(.semibold))
                        ProgressView(value: Double(done), total: Double(store.routines.count))
                            .tint(.green)
                            .accessibilityLabel("Routine progress")
                    }
                    if let first = remainingSteps.first {
                        HStack(spacing: 12) {
                            stepPreview(first, heading: "FIRST")
                            if remainingSteps.count > 1 {
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                                stepPreview(remainingSteps[1], heading: "THEN")
                            }
                        }
                    } else {
                        Label("All done!", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                    }
                }
                Section("My routine") {
                    ForEach(store.routines) { step in
                        HStack(spacing: 12) {
                            Button {
                                store.toggleRoutineStep(step)
                            } label: {
                                HStack(spacing: 16) {
                                    stepPicture(step, size: 48).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(step.title).foregroundStyle(.primary)
                                        if let durationLabel = step.durationLabel {
                                            Text(durationLabel).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if let boardID = step.choiceBoardID,
                                           let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                                            Text("Choices: \(board.title)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(step.isComplete ? .green : .secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .accessibilityLabel("\(step.title), \(step.isComplete ? "done" : "not done")")
                            .buttonStyle(.borderless)
                            Button("Say \(step.title)", systemImage: "speaker.wave.2.fill") {
                                if let audioData = step.audioData { store.playRecorded(audioData) }
                                else { store.speak(step.spokenMessage, language: store.settings.communicationLanguage) }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("routine-speak-step")
                            if let boardID = step.choiceBoardID,
                               let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                                Button("Open choices for \(step.title)", systemImage: "square.grid.2x2.fill") {
                                    store.stopSpeaking()
                                    activeChoiceBoard = board
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("routine-open-choice-board")
                            }
                            if step.videoData != nil {
                                Button("Play video for \(step.title)", systemImage: "play.rectangle.fill") {
                                    store.stopSpeaking()
                                    playingVideoStep = step
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("routine-play-video")
                            }
                            if step.durationSeconds != nil {
                                Button("Open timer for \(step.title)", systemImage: "timer") {
                                    timerPath.append(step.id)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("routine-open-timer")
                            }
                            Menu("More for \(step.title)", systemImage: "ellipsis") {
                                Button("Edit step", systemImage: "pencil") { editingStep = step }
                                Button("No timer") {
                                    store.setRoutineStepDuration(stepID: step.id, durationSeconds: nil)
                                }
                                ForEach(RoutineStep.availableDurations, id: \.self) { seconds in
                                    Button("\(seconds / 60) min") {
                                        store.setRoutineStepDuration(stepID: step.id,
                                                                     durationSeconds: seconds)
                                    }
                                }
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("routine-time-menu")
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.deleteRoutineStep(step) }
                        }
                    }
                    .onMove { source, destination in
                        store.moveRoutineSteps(from: source, to: destination)
                    }
                    Button("Start again", systemImage: "arrow.counterclockwise") { store.resetRoutine() }
                        .disabled(store.routines.allSatisfy { !$0.isComplete })
                }
                Section("Record progress") {
                    Button("Record completed routine", systemImage: "checkmark.seal") {
                        showingRecordSaved = store.recordRoutineRun(outcome: .completed)
                    }
                    .disabled(store.routines.isEmpty || store.routines.contains { !$0.isComplete })
                    .accessibilityIdentifier("routine-record-completed")
                    Button("Record needed more time", systemImage: "clock") {
                        showingRecordSaved = store.recordRoutineRun(outcome: .needsMoreTime)
                    }
                    .disabled(store.routines.isEmpty)
                    .accessibilityIdentifier("routine-record-more-time")
                    NavigationLink {
                        RoutineHistoryView()
                    } label: {
                        Label("Routine history", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("open-routine-history")
                }
                Section("Add a step") {
                    TextField("What happens next?", text: $newStep)
                    TextField("Emoji or symbol", text: $newSymbol)
                    Picker("Time limit", selection: $newDuration) {
                        Text("No timer").tag(0)
                        ForEach(RoutineStep.availableDurations, id: \.self) { seconds in
                            Text("\(seconds / 60) min").tag(seconds)
                        }
                    }
                    .accessibilityIdentifier("routine-new-duration")
                    Button("Add step", systemImage: "plus") {
                        store.addRoutineStep(newStep, symbol: newSymbol,
                                             durationSeconds: newDuration == 0 ? nil : newDuration)
                        newStep = ""
                        newSymbol = "⭐️"
                        newDuration = 0
                    }
                    .disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Waiting timer") {
                    Text("See how much waiting time is left.")
                        .foregroundStyle(.secondary)
                    Picker("Wait for", selection: $waitDuration) {
                        Text("1 min").tag(60)
                        Text("3 min").tag(180)
                        Text("5 min").tag(300)
                        Text("10 min").tag(600)
                    }
                    .onChange(of: waitDuration) { _, value in
                        waitClock = RoutineStepClock(durationSeconds: value)
                        waitNow = Date()
                    }
                    ProgressView(value: Double(waitDuration - waitRemaining), total: Double(waitDuration))
                        .tint(.indigo)
                        .accessibilityLabel("Waiting progress")
                    Text(waitRemaining == 0 ? "All done waiting" : "\(waitRemaining / 60):\(String(format: "%02d", waitRemaining % 60)) left")
                        .font(.title2.monospacedDigit().weight(.semibold))
                    HStack {
                        Button(waitActionTitle, systemImage: waitClock.isRunning ? "pause.fill" : "play.fill") {
                            toggleWaitTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Reset", systemImage: "arrow.counterclockwise") {
                            resetWaitTimer()
                        }
                    }
                    Button("Show waiting timer full screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                        showingFullScreenWait = true
                    }
                    .accessibilityIdentifier("open-full-screen-wait")
                }
            }
            .navigationTitle("My routine")
            .navigationDestination(for: UUID.self) { id in
                if let step = store.routines.first(where: { $0.id == id }) {
                    RoutineStepTimerView(step: step, onOpenSpeak: onOpenSpeak)
                } else {
                    ContentUnavailableView("Step not found", systemImage: "timer")
                }
            }
            .toolbar {
                EditButton()
                Button("New step", systemImage: "plus") { showingNewStepEditor = true }
                    .accessibilityIdentifier("routine-add-detailed-step")
            }
            .sheet(isPresented: $showingNewStepEditor) { RoutineStepEditorView(step: nil) }
            .sheet(item: $editingStep) { RoutineStepEditorView(step: $0) }
            .sheet(item: $playingVideoStep) { SceneHotspotVideoView(step: $0) }
            .sheet(item: $activeChoiceBoard) { board in
                ChoiceBoardSessionView(board: board) {
                    activeChoiceBoard = nil
                    onOpenSpeak()
                }
            }
            .sheet(item: $routinePDF) { payload in
                PrintableBoardsPreview(data: payload.data, title: "Routine PDF",
                                       filename: "Open Voice Routine")
            }
            .fullScreenCover(isPresented: $showingFullScreenWait) {
                FullScreenWaitingTimerView(clock: $waitClock, now: $waitNow,
                                           onToggle: toggleWaitTimer, onReset: resetWaitTimer,
                                           onOpenSpeak: onOpenSpeak)
            }
            .alert("Routine recorded", isPresented: $showingRecordSaved) {
                Button("OK") {}
            } message: {
                Text("You can review or share this record in Routine history.")
            }
            .onReceive(ticker) { _ in
                advanceWaitTimer()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { advanceWaitTimer() }
            }
            .onChange(of: store.activeProfileID) { _, _ in
                newStep = ""
                newSymbol = "⭐️"
                newDuration = 0
                timerPath = []
                editingStep = nil
                playingVideoStep = nil
                activeChoiceBoard = nil
                showingNewStepEditor = false
                routinePDF = nil
                showingRecordSaved = false
                waitClock = RoutineStepClock(durationSeconds: waitDuration)
                waitNow = Date()
                showingFullScreenWait = false
            }
        }
    }

    private func toggleWaitTimer() {
        let date = Date()
        if waitClock.isRunning {
            waitClock.pause(at: date)
        } else if waitClock.secondsRemaining(at: date) == 0 ||
                    waitClock.secondsRemaining(at: date) == waitDuration {
            waitClock.start(at: date)
        } else {
            waitClock.resume(at: date)
        }
        waitNow = date
    }

    private func resetWaitTimer() {
        waitClock.reset()
        waitNow = Date()
    }

    private func advanceWaitTimer() {
        guard waitClock.isRunning else { return }
        waitNow = Date()
        guard waitClock.secondsRemaining(at: waitNow) == 0 else { return }
        waitClock.finish()
        store.speak("All done waiting")
    }

    private func stepPreview(_ step: RoutineStep, heading: String) -> some View {
        VStack(spacing: 6) {
            Text(heading).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            stepPicture(step, size: 48).accessibilityHidden(true)
            Text(step.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(8)
        .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(heading.lowercased()): \(step.title)")
    }

    @ViewBuilder
    private func stepPicture(_ step: RoutineStep, size: CGFloat) -> some View {
        if let imageData = step.displayImageData {
            AsyncThumbnailImage(data: imageData) {
                Text(step.symbol)
                    .font(.system(size: size * 0.7))
            }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text(step.symbol)
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
        }
    }
}

private struct FullScreenWaitingTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CommunicationStore
    @Binding var clock: RoutineStepClock
    @Binding var now: Date
    let onToggle: () -> Void
    let onReset: () -> Void
    let onOpenSpeak: () -> Void

    private var remaining: Int { clock.secondsRemaining(at: now) }
    private var actionTitle: String {
        if clock.isRunning { return "Pause" }
        if remaining == 0 { return "Start again" }
        return remaining == clock.durationSeconds ? "Start" : "Resume"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                HStack {
                    Button("Return to routine", systemImage: "xmark") { dismiss() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("close-full-screen-wait")
                    Spacer()
                    Text("Waiting timer")
                        .font(.headline)
                }
                Spacer(minLength: 12)
                Text(remaining == 0 ? "All done waiting" : "Time left")
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                    .font(.system(size: min(220, max(84, geometry.size.width * 0.23)),
                                  weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityLabel("\(remaining / 60) minutes, \(remaining % 60) seconds left")
                    .accessibilityIdentifier("full-screen-wait-remaining")
                ProgressView(value: Double(clock.durationSeconds - remaining),
                             total: Double(clock.durationSeconds))
                    .tint(store.settings.highContrast ? .black : .indigo)
                    .accessibilityLabel("Waiting progress")
                HStack(spacing: 16) {
                    Button(actionTitle, systemImage: clock.isRunning ? "pause.fill" : "play.fill",
                           action: onToggle)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("full-screen-wait-toggle")
                    Button("Reset", systemImage: "arrow.counterclockwise", action: onReset)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("full-screen-wait-reset")
                }
                .controlSize(.large)
                Spacer(minLength: 12)
                Button("Open Speak", systemImage: "quote.bubble.fill") {
                    dismiss()
                    onOpenSpeak()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("full-screen-wait-open-speak")
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .background(store.settings.highContrast ? Color.white : Color.indigo.opacity(0.08))
        .tint(store.settings.highContrast ? .black : .indigo)
    }
}
