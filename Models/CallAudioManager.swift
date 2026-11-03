import AVFoundation
import Foundation

@MainActor
final class CallAudioManager: ObservableObject {
    @Published private(set) var permission: AVAudioApplication.MicrophoneInjectionPermission = .undetermined
    @Published private(set) var isEnabled = false
    @Published private(set) var isCallAvailable = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    func refresh() {
        let currentPermission = AVAudioApplication.shared.microphoneInjectionPermission
        let session = AVAudioSession.sharedInstance()
        let currentlyEnabled = currentPermission == .granted &&
            session.preferredMicrophoneInjectionMode == .spokenAudio
        let currentlyAvailable = session.isMicrophoneInjectionAvailable
        if permission != currentPermission { permission = currentPermission }
        if isEnabled != currentlyEnabled { isEnabled = currentlyEnabled }
        if isCallAvailable != currentlyAvailable { isCallAvailable = currentlyAvailable }
    }

    func setEnabled(_ wanted: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false; refresh() }
        errorMessage = nil
        if wanted {
            refresh()
            if permission == .undetermined {
                permission = await AVAudioApplication.requestMicrophoneInjectionPermission()
            }
            guard permission == .granted else { return }
        }
        do {
            try await AudioSessionManager.shared.setMicrophoneInjectionMode(wanted ? .spokenAudio : .none)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
