import Foundation

struct ListeningReply: Identifiable, Equatable {
    enum Source: Equatable {
        case personalPhrase
        case quickReply
        case common
    }

    let text: String
    let audioData: Data?
    let source: Source

    var id: String { ListeningReplies.key(for: text) }
}

enum ListeningReplies {
    private static let englishQuestionStarts: Set<String> = [
        "who", "what", "when", "where", "why", "how", "which", "do", "does", "did", "is", "are",
        "can", "could", "would", "will", "should", "have", "has", "may"
    ]
    private static let spanishQuestionStarts: Set<String> = [
        "quien", "que", "cuando", "donde", "por", "como", "cual", "puedes", "quieres", "tienes",
        "hay", "eres", "estas", "vas"
    ]
    private static let commonWords: Set<String> = [
        "a", "an", "and", "are", "can", "could", "do", "does", "for", "i", "is", "it", "me", "my",
        "of", "or", "the", "to", "you", "your", "would", "el", "la", "los", "las", "de", "del",
        "en", "es", "un", "una", "y", "o", "te", "tu", "yo", "que", "por", "para", "con"
    ]

    static func suggestions(for prompt: String, language: String, phrases: [SavedPhrase],
                            quickReplies: [QuickResponse]) -> [ListeningReply] {
        let promptWords = Set(words(in: prompt)).subtracting(commonWords)
        let rankedPhrases = phrases.compactMap { phrase -> (reply: ListeningReply, score: Int)? in
            guard PhraseTemplate.fields(in: phrase.text).isEmpty else { return nil }
            let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let matchCount = Set(words(in: text)).intersection(promptWords).count
            guard matchCount > 0 else { return nil }
            return (ListeningReply(text: text, audioData: phrase.audioData, source: .personalPhrase), matchCount)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.reply.text.count < $1.reply.text.count
        }

        let starts = language == "es" ? spanishQuestionStarts : englishQuestionStarts
        let firstWord = words(in: prompt).first
        let isQuestion = prompt.contains("?") || prompt.contains("¿")
            || firstWord.map { starts.contains($0) } == true
        let common: [String]
        if language == "es" {
            common = isQuestion
                ? ["Sí", "No", "Tal vez", "Necesito tiempo para responder.", "¿Puedes repetirlo?"]
                : ["Te escucho.", "Necesito tiempo para responder.", "¿Puedes repetirlo?"]
        } else {
            common = isQuestion
                ? ["Yes", "No", "Maybe", "I need time to answer.", "Please say that again."]
                : ["I hear you.", "I need time to answer.", "Please say that again."]
        }

        var seen = Set<String>()
        var result: [ListeningReply] = []
        func add(_ reply: ListeningReply) {
            if seen.insert(reply.id).inserted { result.append(reply) }
        }
        for candidate in rankedPhrases.prefix(3) { add(candidate.reply) }
        for reply in quickReplies {
            let text = reply.displayedText(language: language).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { add(ListeningReply(text: text, audioData: reply.audioData, source: .quickReply)) }
        }
        for text in common { add(ListeningReply(text: text, audioData: nil, source: .common)) }
        return Array(result.prefix(14))
    }

    static func key(for text: String) -> String {
        let folded = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return folded.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    private static func words(in text: String) -> [String] {
        key(for: text).split(separator: " ").map(String.init)
    }
}
