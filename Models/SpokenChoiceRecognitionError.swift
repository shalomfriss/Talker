import Foundation

enum SpokenChoiceRecognitionError: LocalizedError {
    case unsupportedLanguage
    case unavailable
    case permissionDenied
    case noSpeech
    case timedOut

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage:
            "On-device speech recognition is not available for this language. Type the choice instead."
        case .unavailable:
            "Speech recognition is not available right now. Try again or type the choice."
        case .permissionDenied:
            "Speech recognition access is needed to turn a spoken choice into text. Allow it in iOS Settings."
        case .noSpeech:
            "No words were recognized. Try again or type the choice."
        case .timedOut:
            "Speech recognition took too long. Try again or type the choice."
        }
    }
}
