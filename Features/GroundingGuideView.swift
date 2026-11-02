import SwiftUI

struct GroundingGuideView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var stepIndex = 0

    private let steps: [(symbol: String, english: String, spanish: String)] = [
        ("👀", "Notice 5 things you can see.", "Observa 5 cosas que puedes ver."),
        ("✋", "Notice 4 things you can feel.", "Observa 4 cosas que puedes sentir."),
        ("👂", "Notice 3 things you can hear.", "Observa 3 cosas que puedes oír."),
        ("👃", "Notice 2 things you can smell.", "Observa 2 cosas que puedes oler."),
        ("👅", "Notice 1 thing you can taste.", "Observa 1 cosa que puedes saborear.")
    ]

    var body: some View {
        let step = steps[stepIndex]
        ScrollView {
            VStack(spacing: 26) {
                Text("Go at your own pace. You can skip a step or stop at any time.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Step \(stepIndex + 1) of \(steps.count)")
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("grounding-step-count")
                Text(step.symbol)
                    .font(.system(size: 74))
                    .accessibilityHidden(true)
                Text(store.settings.communicationLanguage == "es" ? step.spanish : step.english)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityIdentifier("grounding-prompt")
                HStack(spacing: 16) {
                    Button("Previous", systemImage: "chevron.left") { stepIndex -= 1 }
                        .disabled(stepIndex == 0)
                        .accessibilityIdentifier("grounding-previous")
                    Button(stepIndex == steps.count - 1 ? "Start again" : "Next sense",
                           systemImage: stepIndex == steps.count - 1 ? "arrow.counterclockwise" : "chevron.right") {
                        stepIndex = stepIndex == steps.count - 1 ? 0 : stepIndex + 1
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("grounding-next")
                }
                .controlSize(.large)
            }
            .frame(maxWidth: 550)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Five senses grounding")
    }
}
