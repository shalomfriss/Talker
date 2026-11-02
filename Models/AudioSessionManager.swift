import AVFoundation

final class AudioSessionManager: @unchecked Sendable {
    static let shared = AudioSessionManager()

    private let queue = DispatchQueue(label: "org.openvoice.audio-session", qos: .userInitiated)

    private init() {}

    func activateRecording() async throws {
        try await perform { session in
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        }
    }

    func activatePlayback() async throws {
        try await perform { session in
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        }
    }

    func setMicrophoneInjectionMode(_ mode: AVAudioSession.MicrophoneInjectionMode) async throws {
        try await perform { session in
            try session.setPreferredMicrophoneInjectionMode(mode)
        }
    }

    func deactivateSoon() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    private func perform(_ action: @escaping @Sendable (AVAudioSession) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try action(AVAudioSession.sharedInstance())
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
