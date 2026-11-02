import Foundation

enum FeelingMessageComposer {
    private static let spanishStarterPhrases: [String: String] = [
        "happy": "Me siento feliz",
        "sad": "Me siento triste",
        "angry": "Siento enojo",
        "scared": "Tengo miedo",
        "worried": "Siento preocupación",
        "excited": "Siento emoción",
        "tired": "Siento cansancio",
        "overwhelmed": "Siento agobio",
        "calm": "Siento calma",
        "confused": "No entiendo",
        "proud": "Siento orgullo",
        "lonely": "Siento soledad",
        "okay": "Estoy bien",
        "not okay": "No estoy bien"
    ]

    static func message(englishFeeling: String, displayedFeeling: String,
                        language: String, intensity: Int, support: String?) -> String {
        let level: String
        if language == "es" {
            let phrase = spanishStarterPhrases[englishFeeling] ?? "Así me siento: \(displayedFeeling)"
            level = "\(phrase). Intensidad \(intensity) de 5."
        } else {
            level = "I feel \(displayedFeeling). It is a \(intensity) out of 5."
        }
        return support.map { level + " " + $0 } ?? level
    }
}
