import SwiftUI

struct SpeechVolumeView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAdjustingVolume = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Speech output") {
                    Button(store.settings.speechMuted ? "Unmute speech" : "Mute speech",
                           systemImage: store.settings.speechMuted ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                        store.settings.speechMuted.toggle()
                    }
                    .accessibilityValue(store.settings.speechMuted ? "Muted" : "On")
                    .accessibilityIdentifier("speech-mute-button")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App speech volume: \(Int(store.settings.speechVolume * 100))%")
                            .accessibilityIdentifier("speech-volume-value")
                        Slider(value: $store.settings.speechVolume, in: 0.1...1.0, step: 0.05,
                               onEditingChanged: volumeAdjustmentChanged)
                            .accessibilityLabel("App speech volume")
                            .accessibilityIdentifier("speech-volume-slider")
                    }
                    Text("This changes Open Voice speech and saved recordings. Use the device volume buttons for the overall sound level. Ambient sounds have their own volume control.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Try voice", systemImage: "speaker.wave.2.fill") {
                        store.speak(store.settings.communicationLanguage == "es"
                                    ? "Hola. Tengo algo que decir."
                                    : "Hello. I have something to say.")
                    }
                    .disabled(store.settings.speechMuted)
                    .accessibilityIdentifier("speech-volume-try")
                    Button("Stop speaking", systemImage: "stop.fill") { store.stopSpeaking() }
                }
            }
            .navigationTitle("Speech sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("speech-volume-done")
                }
            }
            .onChange(of: store.settings.speechVolume) { _, _ in store.stopSpeaking() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    volumeAdjustmentChanged(false)
                    store.flushPersistence()
                }
            }
            .onDisappear {
                volumeAdjustmentChanged(false)
                store.stopSpeaking()
            }
        }
    }

    private func volumeAdjustmentChanged(_ editing: Bool) {
        guard editing != isAdjustingVolume else { return }
        isAdjustingVolume = editing
        if editing { store.beginSettingsAdjustment() }
        else { store.endSettingsAdjustment() }
    }
}
