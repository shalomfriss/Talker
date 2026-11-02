import AVFoundation
import Combine

enum SoundscapePlaybackError: LocalizedError {
    case missingFile
    case couldNotPlay

    var errorDescription: String? {
        switch self {
        case .missingFile: "This sound is not available in the app."
        case .couldNotPlay: "This sound could not be played."
        }
    }
}

@MainActor
final class SoundscapePlayback: ObservableObject {
    @Published private(set) var current: SoundscapeTrack?
    private var player: AVAudioPlayer?

    func toggle(_ track: SoundscapeTrack, volume: Double) throws {
        if current == track {
            stop()
            return
        }
        stop()
        guard let url = track.fileURL else { throw SoundscapePlaybackError.missingFile }
        let next = try AVAudioPlayer(contentsOf: url)
        next.numberOfLoops = -1
        next.volume = Float(min(0.5, max(0, volume)))
        next.prepareToPlay()
        guard next.play() else { throw SoundscapePlaybackError.couldNotPlay }
        player = next
        current = track
    }

    func setVolume(_ volume: Double) {
        player?.volume = Float(min(0.5, max(0, volume)))
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
    }
}
