import Foundation

enum TypedSpeechPreview {
    static func previews(previous: String, current: String, settings: AppSettings) -> [String] {
        guard current.count == previous.count + 1, String(current.dropLast()) == previous,
              let added = current.last else { return [] }
        var result: [String] = []
        if settings.speakTypedCharacters, !added.isWhitespace {
            result.append(characterName(added, language: settings.communicationLanguage))
        }
        if settings.speakTypedWords, added.isWhitespace || ".?!,;:".contains(added),
           let word = lastWord(in: previous) {
            result.append(word)
        }
        if settings.speakTypedSentences, ".?!\n".contains(added),
           let sentence = lastSentence(in: previous, endingWith: added) {
            result.append(sentence)
        }
        return result
    }

    private static func lastWord(in text: String) -> String? {
        guard let range = text.range(of: #"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*$"#,
                                     options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func lastSentence(in text: String, endingWith ending: Character) -> String? {
        let start = text.lastIndex(where: { ".?!\n".contains($0) })
            .map { text.index(after: $0) } ?? text.startIndex
        let content = text[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        return content + (ending == "\n" ? "" : String(ending))
    }

    private static func characterName(_ character: Character, language: String) -> String {
        let english: [Character: String] = [".": "period", ",": "comma", "?": "question mark",
                                            "!": "exclamation mark", ":": "colon", ";": "semicolon"]
        let spanish: [Character: String] = [".": "punto", ",": "coma", "?": "signo de interrogación",
                                            "!": "signo de exclamación", ":": "dos puntos", ";": "punto y coma",
                                            "¿": "signo de interrogación", "¡": "signo de exclamación"]
        return (language == "es" ? spanish : english)[character] ?? String(character)
    }
}
