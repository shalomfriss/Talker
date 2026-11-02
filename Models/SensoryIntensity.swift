import Foundation

enum SensoryIntensity: String, Codable, CaseIterable, Identifiable {
    case calm = "Calm"
    case balanced = "Balanced"
    case lively = "Lively"

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .calm: 5
        case .balanced: 3.5
        case .lively: 2.5
        }
    }
}
