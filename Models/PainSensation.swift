import Foundation

enum PainSensation: String, CaseIterable, Hashable, Identifiable {
    case aching, sharp, burning, pressure, tingling

    var id: String { rawValue }

    func label(language: String) -> String {
        switch (self, language == "es") {
        case (.aching, false): "Aching"
        case (.aching, true): "Dolor sordo"
        case (.sharp, false): "Sharp"
        case (.sharp, true): "Punzante"
        case (.burning, false): "Burning"
        case (.burning, true): "Ardor"
        case (.pressure, false): "Pressure"
        case (.pressure, true): "Presión"
        case (.tingling, false): "Tingling"
        case (.tingling, true): "Hormigueo"
        }
    }

    func sentence(language: String) -> String {
        switch (self, language == "es") {
        case (.aching, false): "It aches."
        case (.aching, true): "Siento un dolor sordo."
        case (.sharp, false): "It feels sharp."
        case (.sharp, true): "Siento un dolor punzante."
        case (.burning, false): "It burns."
        case (.burning, true): "Siento ardor."
        case (.pressure, false): "It feels like pressure."
        case (.pressure, true): "Siento presión."
        case (.tingling, false): "It tingles."
        case (.tingling, true): "Siento hormigueo."
        }
    }
}
