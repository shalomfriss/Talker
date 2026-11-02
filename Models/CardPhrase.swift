import Foundation

struct CardPhrase: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var spanishText: String = ""

    func resolved(for boardLanguage: String) -> (text: String, language: String) {
        if boardLanguage == "es" && !spanishText.isEmpty {
            return (spanishText, "es")
        }
        return (text, "en")
    }

    static func cleaned(_ values: [CardPhrase]) -> [CardPhrase] {
        var seen = Set<String>()
        return values.compactMap { value in
            var result = value
            result.text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
            result.spanishText = value.spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.text.isEmpty, seen.insert(result.text.folding(options: .caseInsensitive, locale: .current)).inserted
            else { return nil }
            return result
        }
    }
}
