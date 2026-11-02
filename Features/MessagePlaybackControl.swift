import SwiftUI

struct MessagePlaybackControl: View {
    @EnvironmentObject private var store: CommunicationStore
    var source: SpeechHighlightSource?

    var body: some View {
        if let state = store.messagePlaybackState, source == nil || state.source == source {
            HStack(spacing: 12) {
                Button(state.isPaused ? "Resume speech" : "Pause speech",
                       systemImage: state.isPaused ? "play.fill" : "pause.fill") {
                    if state.isPaused { store.resumeMessageSpeech() }
                    else { store.pauseMessageSpeech() }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(state.isPaused ? "resume-message-speech" : "pause-message-speech")
                Spacer(minLength: 0)
                Button("Stop speech", systemImage: "stop.fill") { store.stopSpeaking() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("stop-message-speech")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(store.settings.highContrast ? Color.white : Color(red: 0.94, green: 0.95, blue: 1))
        }
    }
}
