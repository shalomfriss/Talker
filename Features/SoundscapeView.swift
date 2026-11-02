import SwiftUI

struct SoundscapeView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = SoundscapePlayback()
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose one optional sound. It plays only while this screen is open and stops when you leave.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(SoundscapeTrack.allCases) { track in
                    Button {
                        do { try playback.toggle(track, volume: store.settings.soundscapeVolume) }
                        catch { errorMessage = error.localizedDescription }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: track.symbol)
                                .font(.title2)
                                .frame(width: 40)
                            Text(track.title)
                                .font(.headline)
                            Spacer()
                            Image(systemName: playback.current == track ? "stop.fill" : "play.fill")
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .padding(.horizontal, 18)
                        .background(playback.current == track ? Color.indigo.opacity(0.18) : Color.indigo.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(playback.current == track ? "Stop" : "Play") \(track.title)")
                    .accessibilityIdentifier("soundscape-\(track.id)")
                }

                Text(playback.current.map { "Playing \($0.title)" } ?? "No sound playing")
                    .font(.headline)
                    .accessibilityIdentifier("soundscape-status")

                Button("Stop sound", systemImage: "stop.circle.fill") { playback.stop() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(playback.current == nil)
                    .accessibilityIdentifier("soundscape-stop")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume")
                        .font(.headline)
                    Slider(value: $store.settings.soundscapeVolume, in: 0...0.5)
                        .accessibilityIdentifier("soundscape-volume")
                    Text("Keep the volume comfortable. Speech and the communication board remain available from the app tabs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 620)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Ambient sounds")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.settings.soundscapeVolume) { _, newValue in playback.setVolume(newValue) }
        .onChange(of: store.activeProfileID) { _, _ in playback.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { playback.stop() }
        }
        .onDisappear { playback.stop() }
        .alert("Sound unavailable", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
