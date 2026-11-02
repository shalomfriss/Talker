import AVFoundation
import Foundation

enum SpeechHighlightSource: Equatable {
    case picture
    case typed
    case document
    case story(storyID: UUID, pageID: UUID)
}

struct SpeechHighlightState: Equatable {
    let source: SpeechHighlightSource
    let text: String
    var range: NSRange?

    var currentUnit: String? {
        guard let range, Range(range, in: text) != nil else { return nil }
        return (text as NSString).substring(with: range)
    }
}

struct SpeechHighlightSegment {
    let offset: Int
    let length: Int
    let isLast: Bool
}

@MainActor
final class SpeechHighlightDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var store: CommunicationStore?

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.store?.startMessagePlayback(for: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.store?.updateSpeechHighlight(for: id, range: characterRange)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.store?.finishSpeechHighlight(for: id)
            self?.store?.finishMessagePlayback(for: id)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.store?.cancelSpeechHighlight(for: id)
            self?.store?.finishMessagePlayback(for: id)
        }
    }
}

@MainActor
final class RecordedPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    weak var store: CommunicationStore?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        store?.finishRecordedStoryPlayback(for: player, successfully: flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        store?.finishRecordedStoryPlayback(for: player, successfully: false)
    }
}
