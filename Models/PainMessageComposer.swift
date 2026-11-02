import Foundation

enum PainMessageComposer {
    static func message(locations: Set<PainLocation>, sensation: PainSensation?,
                        intensity: Int?, language: String, maximumIntensity: Int = 5) -> String {
        let spanish = language == "es"
        let places = PainLocation.allCases.filter { locations.contains($0) }
            .map { $0.messagePhrase(language: language) }
        let opening: String
        if places.isEmpty {
            opening = spanish ? "Tengo dolor." : "I am in pain."
        } else {
            opening = spanish ? "Tengo dolor en \(joined(places, language: language))."
                              : "I have pain in \(joined(places, language: language))."
        }
        var sentences = [opening]
        if let sensation { sentences.append(sensation.sentence(language: language)) }
        let maximum = maximumIntensity == 10 ? 10 : 5
        if let intensity, (1...maximum).contains(intensity) {
            sentences.append(spanish ? "Intensidad \(intensity) de \(maximum)."
                                     : "Pain level \(intensity) out of \(maximum).")
        }
        return sentences.joined(separator: " ")
    }

    private static func joined(_ phrases: [String], language: String) -> String {
        guard let last = phrases.last else { return "" }
        if phrases.count == 1 { return last }
        let conjunction = language == "es" ? " y " : " and "
        if phrases.count == 2 { return phrases[0] + conjunction + last }
        return phrases.dropLast().joined(separator: ", ") + "," + conjunction + last
    }
}
