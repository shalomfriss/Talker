import AVFoundation
import Foundation

@MainActor
final class CallAudioManager: ObservableObject {
    @Published private(set) var permission: AVAudioApplication.MicrophoneInjectionPermission
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isCallAvailable: Bool
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    init() {
        let initialPermission = AVAudioApplication.shared.microphoneInjectionPermission
        permission = initialPermission
        let session = AVAudioSession.sharedInstance()
        isEnabled = initialPermission == .granted && session.preferredMicrophoneInjectionMode == .spokenAudio
        isCallAvailable = session.isMicrophoneInjectionAvailable
    }

    func refresh() {
        permission = AVAudioApplication.shared.microphoneInjectionPermission
        let session = AVAudioSession.sharedInstance()
        isEnabled = permission == .granted && session.preferredMicrophoneInjectionMode == .spokenAudio
        isCallAvailable = session.isMicrophoneInjectionAvailable
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
