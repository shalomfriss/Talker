import SwiftUI
import Combine

struct BreathingGuideView: View {
    @State private var secondsPerPhase = 4
    @State private var secondsRemaining = 4
    @State private var breathingIn = true
    @State private var isRunning = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        let completed = Double(secondsPerPhase - secondsRemaining) / Double(secondsPerPhase)
        return breathingIn ? completed : 1 - completed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Follow the circle if it feels comfortable. You can pause or leave whenever you want.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Picker("Seconds per breath", selection: $secondsPerPhase) {
                    ForEach([3, 4, 5, 6], id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("breathing-pace")

                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.12), lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: max(0.02, progress))
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Text(breathingIn ? "Breathe in" : "Breathe out")
                            .font(.title.weight(.semibold))
                            .accessibilityIdentifier("breathing-phase")
                        Text("\(secondsRemaining)")
                            .font(.largeTitle.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 240, height: 240)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(breathingIn ? "Breathe in" : "Breathe out"), \(secondsRemaining) seconds remaining")

                HStack(spacing: 14) {
                    Button(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill") {
                        isRunning.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("breathing-start-pause")
                    Button("Reset", systemImage: "arrow.counterclockwise") { reset() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("breathing-reset")
                }
                .controlSize(.large)
                Text("This guide is optional. There is no goal or score.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 500)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Paced breathing")
        .onChange(of: secondsPerPhase) { _, _ in reset() }
        .onReceive(ticker) { _ in
            guard isRunning else { return }
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                breathingIn.toggle()
                secondsRemaining = secondsPerPhase
            }
        }
        .onDisappear { isRunning = false }
    }

    private func reset() {
        isRunning = false
        breathingIn = true
        secondsRemaining = secondsPerPhase
    }
}
