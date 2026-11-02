import AVFoundation
import Foundation

@MainActor
final class AudioMessageRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var requestID = UUID()

    func start() async {
        let currentRequest = UUID()
        requestID = currentRequest
        guard await AVAudioApplication.requestRecordPermission() else {
            if requestID == currentRequest {
                errorMessage = "Microphone access is needed to record a voice. You can allow it in iOS Settings."
            }
            return
        }
        guard requestID == currentRequest else { return }
        do {
            try await AudioSessionManager.shared.activateRecording()
            guard requestID == currentRequest else {
                AudioSessionManager.shared.deactivateSoon()
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record() else { throw AudioRecordingError.couldNotStart }
            self.recorder = recorder
            fileURL = url
            isRecording = true
            errorMessage = nil
        } catch {
            AudioSessionManager.shared.deactivateSoon()
            if requestID == currentRequest { errorMessage = error.localizedDescription }
        }
    }

    func stop() -> Data? {
        guard isRecording, let fileURL else { return nil }
        recorder?.stop()
        recorder = nil
        isRecording = false
        let data = try? Data(contentsOf: fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        self.fileURL = nil
        AudioSessionManager.shared.deactivateSoon()
        return data
    }

    func discard() {
        requestID = UUID()
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        AudioSessionManager.shared.deactivateSoon()
    }
}

private enum AudioRecordingError: LocalizedError {
    case couldNotStart

    var errorDescription: String? { "Recording could not start." }
}
