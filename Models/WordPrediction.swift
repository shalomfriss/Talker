import Foundation

enum WordPrediction {
    private static let wordExpression = try? NSRegularExpression(pattern: #"\p{L}[\p{L}\p{M}'’-]*"#)

    static func suggestions(for text: String, items: [CommunicationItem], phrases: [SavedPhrase],
                            history: [SpokenMessage] = [], learned: LearnedPredictionModel? = nil,
                            language: String = "en", limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        let ordinary: [String]
        if let range = activeWordRange(in: text) {
            ordinary = completions(for: String(text[range]), items: items, phrases: phrases,
                                   history: history, language: language, limit: limit)
        } else {
            guard text.last?.isWhitespace == true else { return [] }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let last = trimmed.last, !".?!".contains(last) else { return [] }
            ordinary = nextWords(after: words(in: trimmed), items: items, phrases: phrases,
                                 history: history, language: language, limit: limit)
        }
        guard let learned else { return ordinary }
        var seen = Set<String>()
        return (learned.suggestions(for: text, language: language, limit: limit) + ordinary)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }

    static func boardItemIDs(after message: String, items: [CommunicationItem], phrases: [SavedPhrase],
                             history: [SpokenMessage] = [], learned: LearnedPredictionModel? = nil,
                             language: String = "en", limit: Int = 4) -> [UUID] {
        let context = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty, limit > 0 else { return [] }
        let availableWords = Set(items.map { $0.message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let next = suggestions(for: context + " ", items: items, phrases: phrases,
                               history: history, learned: learned, language: language, limit: .max)
        let selectedWords = Set(next.map { $0.lowercased() }
            .filter { availableWords.contains($0) }.prefix(limit))
        return items.filter {
            selectedWords.contains($0.message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }.map(\.id)
    }

    private static func completions(for prefixText: String, items: [CommunicationItem],
                                    phrases: [SavedPhrase], history: [SpokenMessage],
                                    language: String, limit: Int) -> [String] {
        let prefix = prefixText.lowercased()
        guard !prefix.isEmpty else { return [] }

        var candidates: [(word: String, rank: Int)] = []
        for item in items {
            let rank = item.category == "Core" ? 0 : (item.isCustom ? 1 : 2)
            candidates += words(in: item.label).map { ($0, rank) }
            candidates += words(in: item.message).map { ($0, rank + 1) }
        }
        for phrase in phrases {
            if !phrase.text.contains("{") { candidates += words(in: phrase.text).map { ($0, 1) } }
        }
        for item in items {
            for phrase in item.phraseOptions ?? [] {
                candidates += words(in: phrase.resolved(for: language).text).map { ($0, 1) }
            }
        }
        for message in history { candidates += words(in: message.text).map { ($0, 1) } }

        var best: [String: (word: String, rank: Int)] = [:]
        for candidate in candidates where candidate.word.lowercased().hasPrefix(prefix)
            && candidate.word.lowercased() != prefix {
            let key = candidate.word.lowercased()
            if let existing = best[key], candidate.rank >= existing.rank { continue }
            else {
                best[key] = candidate
            }
        }
        return best.values.sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
        }
        .prefix(max(0, limit))
        .map(\.word)
    }

    private static func nextWords(after context: [String], items: [CommunicationItem],
                                  phrases: [SavedPhrase], history: [SpokenMessage],
                                  language: String, limit: Int) -> [String] {
        guard let previous = context.last?.lowercased() else { return [] }
        let earlier = context.dropLast().last?.lowercased()
        var sources: [(text: String, weight: Int)] = []
        sources += items.map { ($0.message, 1) }
        sources += phrases.filter { !$0.text.contains("{") }.map { ($0.text, 2) }
        for item in items {
            sources += (item.phraseOptions ?? []).map { ($0.resolved(for: language).text, 2) }
        }
        sources += history.enumerated().map { ($0.element.text, $0.offset < 10 ? 4 : 3) }

        var scores: [String: (word: String, score: Int)] = [:]
        for source in sources {
            let tokens = words(in: source.text)
            guard tokens.count > 1 else { continue }
            for index in 1..<tokens.count where tokens[index - 1].lowercased() == previous {
                let strong = index > 1 && (earlier.map { tokens[index - 2].lowercased() == $0 } ?? false)
                let word = tokens[index]
                let key = word.lowercased()
                let points = source.weight * (strong ? 8 : 2)
                let old = scores[key]
                scores[key] = (old?.word ?? word, (old?.score ?? 0) + points)
            }
        }
        return scores.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
        }
        .prefix(max(0, limit))
        .map(\.word)
    }

    static func completing(_ text: String, with suggestion: String) -> String {
        if let range = activeWordRange(in: text) {
            var result = text
            result.replaceSubrange(range, with: suggestion)
            return result + " "
        }
        if text.last?.isWhitespace == true { return text + suggestion + " " }
        return text
    }

    private static func activeWordRange(in text: String) -> Range<String.Index>? {
        text.range(of: #"\p{L}[\p{L}\p{M}'’-]*$"#, options: .regularExpression)
    }

    private static func words(in text: String) -> [String] {
        guard let expression = wordExpression else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
