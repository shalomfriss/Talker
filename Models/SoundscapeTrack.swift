import Foundation

enum SoundscapeTrack: String, CaseIterable, Identifiable {
    case rain = "Rain"
    case waves = "Waves"
    case breeze = "Breeze"

    var id: String { rawValue.lowercased() }

    var title: String {
        switch self {
        case .rain: "Soft rain"
        case .waves: "Slow waves"
        case .breeze: "Breeze"
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.rain"
        case .waves: "water.waves"
        case .breeze: "wind"
        }
    }

    var fileURL: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "wav", subdirectory: "Soundscapes")
    }
}
