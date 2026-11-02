import Foundation
import Speech

@MainActor
final class SpokenChoiceTranscriber {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var temporaryURL: URL?

    func prepare(language: String) async throws {
        let status = await Self.authorizationStatus()
        guard status == .authorized else { throw SpokenChoiceRecognitionError.permissionDenied }
        let locale = Locale(identifier: language == "es" ? "es-ES" : "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition else {
            throw SpokenChoiceRecognitionError.unsupportedLanguage
        }
        guard recognizer.isAvailable else { throw SpokenChoiceRecognitionError.unavailable }
        self.recognizer = recognizer
    }

    nonisolated private static func authorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribe(_ audioData: Data) async throws -> String {
        guard let recognizer else { throw SpokenChoiceRecognitionError.unavailable }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try audioData.write(to: url, options: .atomic)
        temporaryURL = url
        defer { cleanUp() }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let transcript: String = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    self?.handle(result: result, error: error)
                }
            }
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.finish(.failure(SpokenChoiceRecognitionError.timedOut))
            }
        }
        let cleaned = SpokenChoiceText.cleaned(transcript)
        guard !cleaned.isEmpty else { throw SpokenChoiceRecognitionError.noSpeech }
        return cleaned
    }

    func cancel() {
        recognitionTask?.cancel()
        finish(.failure(CancellationError()))
        cleanUp()
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            finish(.failure(error))
        } else if let result, result.isFinal {
            finish(.success(result.bestTranscription.formattedString))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(with: result)
    }

    private func cleanUp() {
        recognitionTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
        temporaryURL = nil
    }
}
