enum MessagePlaybackState: Equatable {
    case playing(SpeechHighlightSource)
    case paused(SpeechHighlightSource)

    var source: SpeechHighlightSource {
        switch self {
        case .playing(let source), .paused(let source): source
        }
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}
