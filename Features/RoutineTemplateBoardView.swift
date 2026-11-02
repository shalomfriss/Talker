import Combine
import SwiftUI

struct RoutineTemplateBoardView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    private let templateID: UUID
    private let title: String
    private let onOpenSpeak: () -> Void
    @State private var session: FirstThenSession
    @State private var layout: FirstThenLayout
    @State private var mode: RoutineBoardMode
    @State private var clock: RoutineStepClock?
    @State private var now = Date()
    @State private var routinePDF: PDFPreviewPayload?
    @State private var playingVideoStep: RoutineStep?
    @State private var activeChoiceBoard: ChoiceBoard?
    @State private var rewardAwardedForRun = false
    @State private var rewardNotice: String?
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(template: RoutineTemplate, onOpenSpeak: @escaping () -> Void) {
        templateID = template.id
        title = template.name
        self.onOpenSpeak = onOpenSpeak
        _session = State(initialValue: FirstThenSession(template: template))
        _layout = State(initialValue: template.firstThenLayout)
        _mode = State(initialValue: template.boardMode)
        _clock = State(initialValue: template.steps.first?.durationSeconds.map(RoutineStepClock.init(durationSeconds:)))
    }

    private var isStacked: Bool {
        switch layout {
        case .automatic: sizeClass == .compact
        case .sideBySide: false
        case .stacked: true
        }
    }

    private var compactCards: Bool { sizeClass == .compact && isStacked }

    private var secondsRemaining: Int { clock?.secondsRemaining(at: now) ?? 0 }

    private var timerActionTitle: String {
        guard let clock else { return "Start" }
        if clock.isRunning { return "Pause" }
        if secondsRemaining == clock.durationSeconds { return "Start" }
        if secondsRemaining == 0 { return "Start again" }
        return "Resume"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: compactCards ? 16 : 24) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("\(session.completedCount) of \(session.steps.count) \(session.steps.count == 1 ? "step" : "steps") done")
                        .font(.subheadline.weight(.semibold))
                    ProgressView(value: Double(session.completedCount),
                                 total: Double(max(1, session.steps.count)))
                        .tint(.green)
                        .accessibilityLabel("First/Then progress")
                    if let chartID = store.routineTemplates.first(where: { $0.id == templateID })?.rewardChartID,
                       let chart = store.rewardCharts.first(where: { $0.id == chartID }) {
                        Text("\(chart.symbol) \(chart.title): \(chart.earnedTokens) of \(chart.targetTokens) tokens")
                            .font(.subheadline)
                            .accessibilityIdentifier("first-then-reward-progress")
                    }
                    if let rewardNotice {
                        Text(rewardNotice)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("first-then-reward-notice")
                    }
                }
                .frame(maxWidth: .infinity)

                Picker("View routine as", selection: $mode) {
                    ForEach(RoutineBoardMode.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("routine-board-mode")
                .onChange(of: mode) { _, selected in
                    store.setRoutineTemplateMode(id: templateID, mode: selected)
                }

                if mode == .firstThen {
                    Picker("Board layout", selection: $layout) {
                        ForEach(FirstThenLayout.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("first-then-layout")
                    .onChange(of: layout) { _, selected in
                        store.setRoutineTemplateLayout(id: templateID, layout: selected)
                    }
                }

                switch mode {
                case .firstThen:
                    firstThenContent
                case .singleStep:
                    singleStepContent
                case .checklist:
                    checklistContent
                case .columns:
                    columnsContent
                case .envelope:
                    envelopeContent
                }

                if let first = session.current {
                    if let clock {
                        timerControls(clock: clock, step: first)
                    }
                    if mode == .firstThen || mode == .singleStep {
                        Button("Mark \(first.title) done", systemImage: "checkmark.circle.fill") {
                            setStepComplete(first, to: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("first-then-done")
                    }
                }

                Button("Start again", systemImage: "arrow.counterclockwise") {
                    session.reset()
                    rewardAwardedForRun = false
                    rewardNotice = nil
                    clock = session.current?.durationSeconds.map(RoutineStepClock.init(durationSeconds:))
                    now = .now
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(session.completedCount == 0)
                .accessibilityIdentifier("first-then-reset")
            }
            .frame(maxWidth: 900)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("First/Then board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Printable PDF", systemImage: "doc.richtext") {
                routinePDF = PDFPreviewPayload(data: PrintableRoutinePDF.makeData(
                    profileName: store.activeProfileName, steps: session.snapshotSteps,
                    language: store.settings.communicationLanguage))
            }
            .accessibilityIdentifier("first-then-print")
        }
        .sheet(item: $routinePDF) { payload in
            PrintableBoardsPreview(data: payload.data, title: "Routine PDF",
                                   filename: "Open Voice \(title)")
        }
        .sheet(item: $playingVideoStep) { SceneHotspotVideoView(step: $0) }
        .sheet(item: $activeChoiceBoard) { board in
            ChoiceBoardSessionView(board: board) {
                activeChoiceBoard = nil
                onOpenSpeak()
            }
        }
        .onReceive(ticker) { _ in advanceTime() }
        .onChange(of: scenePhase) { _, _ in advanceTime() }
        .onChange(of: store.activeProfileID) { _, _ in dismiss() }
    }

    @ViewBuilder
    private var firstThenContent: some View {
        if let first = session.current {
            let pairLayout = isStacked
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            pairLayout {
                panel(first, heading: "FIRST")
                Image(systemName: isStacked ? "arrow.down" : "arrow.right")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                panel(session.next, heading: "THEN")
            }
            Text("Tap a panel to hear its instruction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else { allDone }
    }

    @ViewBuilder
    private var singleStepContent: some View {
        if let first = session.current {
            panel(first, heading: "NOW", expanded: true)
                .frame(maxWidth: 650)
            Text("One step at a time. Tap the picture to hear its instruction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else { allDone }
    }

    private var checklistContent: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text("Mark any step when it is done. Tap its speaker to hear the instruction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(session.steps) { step in
                stepCard(step)
            }
        }
    }

    private var columnsContent: some View {
        let arrangement = sizeClass == .compact
            ? AnyLayout(VStackLayout(spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return arrangement {
            completionColumn("TO DO", steps: session.remainingSteps, moveToDone: false)
            completionColumn("DONE", steps: session.completedSteps, moveToDone: true)
        }
    }

    private func completionColumn(_ heading: String, steps: [RoutineStep],
                                  moveToDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(heading).font(.headline.weight(.bold))
                Spacer()
                Text("\(steps.count)").font(.subheadline.monospacedDigit())
            }
            if steps.isEmpty {
                Text(moveToDone ? "Drag a step here when it is done." : "All steps are done.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
            ForEach(steps) { step in
                stepCard(step).draggable(step.id.uuidString)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(moveToDone ? Color.green.opacity(0.09) : Color.indigo.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16))
        .dropDestination(for: String.self) { items, _ in
            moveDroppedStep(items, to: moveToDone)
        }
    }

    private var envelopeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sizeClass == .compact { envelopeDropZone }
            Text("STEP STRIP")
                .font(.headline.weight(.bold))
            if session.remainingSteps.isEmpty {
                Text("All steps are in the envelope.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(session.remainingSteps) { step in
                            envelopeTile(step).draggable(step.id.uuidString)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .dropDestination(for: String.self) { items, _ in
                    moveDroppedStep(items, to: false)
                }
            }
            if sizeClass != .compact { envelopeDropZone }
        }
    }

    private var envelopeDropZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Done envelope", systemImage: "envelope.fill")
                .font(.title2.weight(.bold))
            Text("Drag a step into the envelope, or use its Put in envelope button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if session.completedSteps.isEmpty {
                Text("The envelope is empty.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            }
            ForEach(session.completedSteps) { step in
                stepCard(step).draggable(step.id.uuidString)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
        .dropDestination(for: String.self) { items, _ in
            moveDroppedStep(items, to: true)
        }
    }

    private func envelopeTile(_ step: RoutineStep) -> some View {
        VStack(spacing: 10) {
            stepPicture(step, size: 78)
            Text(step.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Button("Put \(step.title) in envelope", systemImage: "envelope.badge") {
                setStepComplete(step, to: true)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("routine-board-envelope-complete")
            stepActions(step)
        }
        .padding(12)
        .frame(width: 220)
        .frame(minHeight: 215)
        .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func stepCard(_ step: RoutineStep) -> some View {
        let complete = session.isComplete(step)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(complete ? "Move \(step.title) back to To do" : "Mark \(step.title) done",
                       systemImage: complete ? "checkmark.circle.fill" : "circle") {
                    setStepComplete(step, to: !complete)
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier(complete ? "routine-board-undo-step" : "routine-board-complete-step")
                stepPicture(step, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title).font(.headline)
                    if let duration = step.durationLabel {
                        Text(duration).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            stepActions(step)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(complete ? Color.green.opacity(0.12) : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.25)))
    }

    private func stepPicture(_ step: RoutineStep, size: CGFloat) -> some View {
        Group {
            if let data = step.displayImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(step.symbol).font(.system(size: size * 0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private func stepActions(_ step: RoutineStep) -> some View {
        HStack(spacing: 8) {
            Button("Say \(step.title)", systemImage: "speaker.wave.2.fill") {
                if let audioData = step.audioData { store.playRecorded(audioData) }
                else { store.speak(step.spokenMessage, language: store.settings.communicationLanguage) }
            }
            .accessibilityIdentifier("routine-board-speak-step")
            if step.videoData != nil {
                Button("Play video for \(step.title)", systemImage: "play.rectangle.fill") {
                    store.stopSpeaking()
                    playingVideoStep = step
                }
            }
            if let boardID = step.choiceBoardID,
               let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                Button("Open choices for \(step.title)", systemImage: "square.grid.2x2.fill") {
                    store.stopSpeaking()
                    activeChoiceBoard = board
                }
            }
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .controlSize(.large)
    }

    private var allDone: some View {
        Label("All done!", systemImage: "checkmark.circle.fill")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func setStepComplete(_ step: RoutineStep, to complete: Bool) {
        let previousCurrent = session.current?.id
        guard session.setComplete(step.id, to: complete) else { return }
        if complete, session.completedCount == session.steps.count, !rewardAwardedForRun {
            rewardAwardedForRun = true
            if let chart = store.awardRoutineCompletion(templateID: templateID) {
                rewardNotice = chart.isComplete
                    ? "Token added. \(chart.title) is ready to collect in Reward charts."
                    : "Token added to \(chart.title)."
            }
        }
        if session.current?.id != previousCurrent {
            clock = session.current?.durationSeconds.map(RoutineStepClock.init(durationSeconds:))
        }
        now = .now
    }

    private func moveDroppedStep(_ items: [String], to complete: Bool) {
        guard let value = items.first, let id = UUID(uuidString: value),
              let step = session.steps.first(where: { $0.id == id }),
              session.isComplete(step) != complete else { return }
        setStepComplete(step, to: complete)
    }

    private func panel(_ step: RoutineStep?, heading: String, expanded: Bool = false) -> some View {
        let useCompact = compactCards && !expanded
        return VStack(spacing: useCompact ? 6 : 12) {
            Text(heading)
                .font(expanded ? .title2.weight(.heavy) : .headline.weight(.heavy))
                .foregroundStyle(.secondary)
            if let step {
                Button {
                    if let audioData = step.audioData { store.playRecorded(audioData) }
                    else { store.speak(step.spokenMessage, language: store.settings.communicationLanguage) }
                } label: {
                    VStack(spacing: 10) {
                        if let imageData = step.displayImageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: expanded ? 250 : (useCompact ? 72 : 145))
                                .accessibilityHidden(true)
                        } else {
                            Text(step.symbol)
                                .font(.system(size: expanded ? 150 : (useCompact ? 62 : 96)))
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity)
                                .frame(height: expanded ? 250 : (useCompact ? 72 : 145))
                                .accessibilityHidden(true)
                        }
                        Text(step.title)
                            .font(expanded ? .title.weight(.semibold) :
                                  (useCompact ? .headline.weight(.semibold) : .title3.weight(.semibold)))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                        if let duration = step.durationLabel {
                            Text(duration).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: expanded ? 330 : (useCompact ? 110 : 210))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(heading.lowercased()): \(step.title). Speak instruction")
                .accessibilityIdentifier("first-then-\(heading.lowercased())-speak")
                if step.videoData != nil {
                    Button("Play video for \(step.title)", systemImage: "play.rectangle.fill") {
                        store.stopSpeaking()
                        playingVideoStep = step
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("first-then-\(heading.lowercased())-video")
                }
                if let boardID = step.choiceBoardID,
                   let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                    Button("Open choices for \(step.title)", systemImage: "square.grid.2x2.fill") {
                        store.stopSpeaking()
                        activeChoiceBoard = board
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("first-then-\(heading.lowercased())-choices")
                }
            } else {
                Label("All done after this", systemImage: "checkmark.circle")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: expanded ? 330 : (useCompact ? 110 : 210))
            }
        }
        .padding(useCompact ? 10 : 16)
        .frame(maxWidth: .infinity)
        .background(Color.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
    }

    private func timerControls(clock: RoutineStepClock, step: RoutineStep) -> some View {
        VStack(spacing: 10) {
            Text(secondsRemaining == 0 ? "Time is up" :
                 "\(secondsRemaining / 60):\(String(format: "%02d", secondsRemaining % 60)) left")
                .font(.title.monospacedDigit().weight(.bold))
                .accessibilityIdentifier("first-then-time-remaining")
            ProgressView(value: Double(clock.durationSeconds - secondsRemaining),
                         total: Double(clock.durationSeconds))
                .tint(.indigo)
                .accessibilityLabel("First step timer progress")
            HStack(spacing: 12) {
                Button(timerActionTitle, systemImage: clock.isRunning ? "pause.fill" : "play.fill") {
                    guard var updated = self.clock else { return }
                    let date = Date()
                    if updated.isRunning { updated.pause(at: date) }
                    else if secondsRemaining == 0 || secondsRemaining == updated.durationSeconds {
                        updated.start(at: date)
                    } else { updated.resume(at: date) }
                    self.clock = updated
                    now = date
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("first-then-timer-toggle")
                Button("Reset timer", systemImage: "arrow.counterclockwise") {
                    var updated = clock
                    updated.reset()
                    self.clock = updated
                    now = .now
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Timer for \(step.title)")
    }

    private func advanceTime() {
        now = .now
        guard var active = clock, active.isRunning, active.secondsRemaining(at: now) == 0 else { return }
        active.finish()
        clock = active
        if let current = session.current { store.speak("Time is up for \(current.title)") }
    }
}
