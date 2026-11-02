import Foundation

enum TypedWordForms {
    struct Context: Identifiable, Equatable {
        let id = UUID()
        let word: String
        let startOffset: Int
        let endOffset: Int
        let language: String

        var options: [EnglishWordForms.Option] {
            language == "es" ? SpanishWordForms.options(for: word) : EnglishWordForms.options(for: word)
        }
    }

    static func context(in text: String, cursorOffset: Int, language: String = "en") -> Context? {
        guard language == "en" || language == "es" else { return nil }
        let characters = Array(text)
        guard cursorOffset >= 0, cursorOffset <= characters.count else { return nil }
        var position = cursorOffset

        if position < characters.count, isWordLetter(characters[position], language: language) {
            // Use the word under the cursor, including when the cursor is at its start.
        } else if position > 0, isWordLetter(characters[position - 1], language: language) {
            // Use the word immediately before the cursor.
        } else if position == characters.count {
            while position > 0, characters[position - 1].isWhitespace { position -= 1 }
            guard position > 0, isWordLetter(characters[position - 1], language: language) else { return nil }
        } else {
            return nil
        }

        var start = position
        while start > 0, isWordLetter(characters[start - 1], language: language) { start -= 1 }
        var end = position
        while end < characters.count, isWordLetter(characters[end], language: language) { end += 1 }
        if start > 0, characters[start - 1].isLetter || "'’".contains(characters[start - 1]) {
            return nil
        }
        if end < characters.count, characters[end].isLetter || "'’".contains(characters[end]) {
            return nil
        }
        let word = String(characters[start..<end])
        let options = language == "es" ? SpanishWordForms.options(for: word) : EnglishWordForms.options(for: word)
        guard !options.isEmpty else { return nil }
        return Context(word: word, startOffset: start, endOffset: end, language: language)
    }

    static func replacing(_ text: String, context: Context,
                          with option: EnglishWordForms.Option) -> (text: String, cursorOffset: Int)? {
        let characters = Array(text)
        guard context.startOffset >= 0, context.endOffset <= characters.count,
              context.startOffset < context.endOffset,
              String(characters[context.startOffset..<context.endOffset]) == context.word,
              context.options.contains(where: { $0.kind == option.kind && $0.text == option.text })
        else { return nil }
        let updated = String(characters[..<context.startOffset]) + option.text
            + String(characters[context.endOffset...])
        return (updated, context.startOffset + option.text.count)
    }

    private static func isWordLetter(_ character: Character, language: String) -> Bool {
        let allowed = language == "es"
            ? CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZáéíóúüñÁÉÍÓÚÜÑ")
            : CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return character.unicodeScalars.allSatisfy(allowed.contains)
    }
}
