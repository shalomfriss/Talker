import Combine
import SwiftUI

struct RoutineStepTimerView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    let stepID: UUID
    let onOpenSpeak: () -> Void
    @State private var clock: RoutineStepClock
    @State private var now = Date()
    @State private var playingVideoStep: RoutineStep?
    @State private var activeChoiceBoard: ChoiceBoard?
    @ScaledMetric private var timerFontSize: CGFloat = 66
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(step: RoutineStep, onOpenSpeak: @escaping () -> Void) {
        stepID = step.id
        self.onOpenSpeak = onOpenSpeak
        _clock = State(initialValue: RoutineStepClock(durationSeconds: step.durationSeconds ?? 60))
    }

    private var step: RoutineStep? { store.routines.first { $0.id == stepID } }
    private var secondsRemaining: Int { clock.secondsRemaining(at: now) }
    private var timerActionTitle: String {
        if clock.isRunning { return "Pause" }
        if secondsRemaining == clock.durationSeconds { return "Start" }
        if secondsRemaining == 0 { return "Start again" }
        return "Resume"
    }

    var body: some View {
        Group {
            if let step {
                ScrollView {
                    VStack(spacing: 24) {
                        if let imageData = step.displayImageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 180, maxHeight: 180)
                                .accessibilityHidden(true)
                        } else {
                            Text(step.symbol)
                                .font(.system(size: 90))
                                .accessibilityHidden(true)
                        }
                        Text(step.title)
                            .font(.title.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if step.videoData != nil {
                            Button("Play video for \(step.title)", systemImage: "play.rectangle.fill") {
                                store.stopSpeaking()
                                playingVideoStep = step
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("routine-timer-play-video")
                        }
                        if let boardID = step.choiceBoardID,
                           let board = store.choiceBoards.first(where: { $0.id == boardID }) {
                            Button("Open choices for \(step.title)", systemImage: "square.grid.2x2.fill") {
                                store.stopSpeaking()
                                activeChoiceBoard = board
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("routine-timer-open-choice-board")
                        }
                        Text(secondsRemaining == 0 ? "Time is up" :
                             "\(secondsRemaining / 60):\(String(format: "%02d", secondsRemaining % 60))")
                            .font(.system(size: timerFontSize, weight: .bold, design: .rounded).monospacedDigit())
                            .minimumScaleFactor(0.7)
                            .accessibilityLabel(secondsRemaining == 0 ? "Time is up" :
                                                "\(secondsRemaining / 60) minutes, \(secondsRemaining % 60) seconds left")
                            .accessibilityIdentifier("routine-time-remaining")
                        ProgressView(value: Double(clock.durationSeconds - secondsRemaining),
                                     total: Double(clock.durationSeconds))
                            .tint(.indigo)
                            .accessibilityLabel("Step timer progress")
                        HStack(spacing: 18) {
                            Button(timerActionTitle,
                                   systemImage: clock.isRunning ? "pause.fill" : "play.fill") {
                                let date = Date()
                                if clock.isRunning { clock.pause(at: date) }
                                else if secondsRemaining == 0 || secondsRemaining == clock.durationSeconds {
                                    clock.start(at: date)
                                } else { clock.resume(at: date) }
                                now = Date()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("routine-timer-toggle")
                            Button("Reset", systemImage: "arrow.counterclockwise") {
                                clock.reset()
                                now = Date()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                        Button(step.isComplete ? "Mark not done" : "Mark step done",
                               systemImage: step.isComplete ? "circle" : "checkmark.circle") {
                            store.toggleRoutineStep(step)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: 520)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Step not found", systemImage: "timer")
            }
        }
        .navigationTitle("Step timer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playingVideoStep) { SceneHotspotVideoView(step: $0) }
        .sheet(item: $activeChoiceBoard) { board in
            ChoiceBoardSessionView(board: board) {
                activeChoiceBoard = nil
                onOpenSpeak()
            }
        }
        .onReceive(ticker) { _ in advanceTime() }
        .onChange(of: scenePhase) { _, _ in advanceTime() }
    }

    private func advanceTime() {
        now = Date()
        guard clock.isRunning, clock.secondsRemaining(at: now) == 0 else { return }
        clock.finish()
        if let step { store.speak("Time is up for \(step.title)") }
    }
}
