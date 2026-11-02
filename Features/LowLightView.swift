import SwiftUI

struct LowLightView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CommunicationStore
    let need: CalmNeed?
    let language: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("Low light")
                    .font(.title2)
                    .foregroundStyle(.gray)
                if let need {
                    Text(need.text(language: language))
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("low-light-message")
                    Button("Speak request", systemImage: "speaker.wave.2.fill") {
                        store.speak(need.text(language: language), language: language)
                    }
                    .accessibilityIdentifier("low-light-speak")
                }
                Spacer()
                Button("Return to Calm space", systemImage: "xmark.circle") { dismiss() }
                    .accessibilityIdentifier("low-light-close")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.gray)
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }
}
