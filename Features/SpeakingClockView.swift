import SwiftUI

struct SpeakingClockView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let language = store.settings.communicationLanguage
                let currentTime = SpokenClock.time(at: context.date, language: language)
                let currentDate = SpokenClock.date(at: context.date, language: language)
                VStack(spacing: 24) {
                    Text(currentDate)
                        .font(.title2.weight(.medium))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("speaking-clock-date")

                    Button {
                        store.speak(SpokenClock.message(at: Date(), language: language),
                                    language: language)
                    } label: {
                        VStack(spacing: 28) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 68))
                            Text(currentTime)
                                .font(.system(size: 82, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Label(language == "es" ? "Decir la hora" : "Speak the time",
                                  systemImage: "speaker.wave.2.fill")
                                .font(.title2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                        .foregroundStyle(store.settings.highContrast ? Color.white : Color.primary)
                        .background(store.settings.highContrast ? Color.black : Color(red: 0.89, green: 0.94, blue: 1),
                                    in: RoundedRectangle(cornerRadius: 30))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("speak-current-time")
                    .accessibilityLabel(language == "es" ? "Decir la hora: \(currentTime)"
                                        : "Speak the time: \(currentTime)")
                }
                .padding(24)
            }
            .navigationTitle(store.settings.communicationLanguage == "es" ? "Reloj" : "Clock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
