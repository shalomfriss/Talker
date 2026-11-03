import Foundation

enum SentencePrediction {
    private struct ActiveSentence {
        let range: Range<String.Index>
        let prefix: String
    }

    static func suggestions(for text: String, phrases: [SavedPhrase],
                            quickResponses: [QuickResponse] = [], history: [SpokenMessage] = [],
                            learned: LearnedPredictionModel? = nil,
                            language: String = "en", limit: Int = 4) -> [String] {
        guard let active = activeSentence(in: text), limit > 0 else { return [] }
        let prefix = searchKey(active.prefix)
        var scores: [String: (text: String, score: Int, order: Int)] = [:]
        var order = 0

        func consider(_ text: String, weight: Int) {
            defer { order += 1 }
            let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.count <= 300, !candidate.contains("{") else { return }
            let key = searchKey(candidate)
            guard key.hasPrefix(prefix), key != prefix,
                  candidate.split(whereSeparator: \.isWhitespace).count >= 2 else { return }
            if let existing = scores[key] {
                scores[key] = (existing.text, existing.score + weight, existing.order)
            } else {
                scores[key] = (candidate, weight, order)
            }
        }

        for phrase in phrases { consider(phrase.text, weight: 10) }
        for response in quickResponses {
            consider(response.displayedText(language: language), weight: 8)
        }
        for (index, message) in history.lazy.filter({ $0.speaker != .partner }).prefix(50).enumerated() {
            consider(message.text, weight: index < 10 ? 5 : 3)
        }
        if let learned {
            for sentence in learned.sentenceCompletions(for: active.prefix, language: language,
                                                       limit: limit) {
                consider(sentence, weight: 6)
            }
        }
        return scores.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending
        }
        .prefix(limit)
        .map(\.text)
    }

    static func completing(_ text: String, with suggestion: String) -> String? {
        guard let active = activeSentence(in: text) else { return nil }
        let candidateKey = searchKey(suggestion)
        let prefix = searchKey(active.prefix)
        guard candidateKey.hasPrefix(prefix), candidateKey != prefix else { return nil }
        var result = text
        result.replaceSubrange(active.range, with: suggestion)
        return result
    }

    private static func activeSentence(in text: String) -> ActiveSentence? {
        let boundary = text.lastIndex { ".?!\n".contains($0) }
        let start = boundary.map { text.index(after: $0) } ?? text.startIndex
        let segment = text[start...]
        let leadingWhitespace = segment.prefix(while: \.isWhitespace)
        let contentStart = text.index(start, offsetBy: leadingWhitespace.count)
        let prefix = String(text[contentStart...])
        guard prefix.count <= 200,
              prefix.filter({ !$0.isWhitespace }).count >= 3 else { return nil }
        return ActiveSentence(range: contentStart..<text.endIndex, prefix: prefix)
    }

    private static func searchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
