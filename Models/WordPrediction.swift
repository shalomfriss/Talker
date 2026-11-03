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
        guard let last = context.last, !".?!".contains(last) else { return [] }
        let availableWords = Set(items.map { $0.message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let ordinary = nextWords(after: words(in: context), items: items, phrases: phrases,
                                 history: history, language: language, limit: limit,
                                 allowedWords: availableWords)
        let learnedWords = learned?.suggestions(for: context + " ", language: language,
                                                limit: limit, allowedWords: availableWords) ?? []
        var seen = Set<String>()
        let selectedWords = Set((learnedWords + ordinary).map { $0.lowercased() }
            .filter { seen.insert($0).inserted }.prefix(limit))
        return items.filter {
            selectedWords.contains($0.message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }.map(\.id)
    }

    private static func completions(for prefixText: String, items: [CommunicationItem],
                                    phrases: [SavedPhrase], history: [SpokenMessage],
                                    language: String, limit: Int) -> [String] {
        let prefix = prefixText.lowercased()
        guard !prefix.isEmpty else { return [] }

        var best: [String: (word: String, rank: Int)] = [:]
        func consider(_ word: String, rank: Int) {
            let key = word.lowercased()
            guard key.hasPrefix(prefix), key != prefix else { return }
            if let existing = best[key], existing.rank <= rank { return }
            best[key] = (word, rank)
        }
        func considerWords(in text: String, rank: Int) {
            guard text.lowercased().contains(prefix) else { return }
            for word in words(in: text) { consider(word, rank: rank) }
        }
        for item in items {
            let rank = item.category == "Core" ? 0 : (item.isCustom ? 1 : 2)
            considerWords(in: item.label, rank: rank)
            considerWords(in: item.message, rank: rank + 1)
        }
        for phrase in phrases {
            if !phrase.text.contains("{") {
                considerWords(in: phrase.text, rank: 1)
            }
        }
        for item in items {
            for phrase in item.phraseOptions ?? [] {
                considerWords(in: phrase.resolved(for: language).text, rank: 1)
            }
        }
        for message in history where message.speaker != .partner {
            considerWords(in: message.text, rank: 1)
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
                                  language: String, limit: Int,
                                  allowedWords: Set<String>? = nil) -> [String] {
        guard let previous = context.last?.lowercased() else { return [] }
        let earlier = context.dropLast().last?.lowercased()
        var scores: [String: (word: String, score: Int)] = [:]
        func accumulate(_ text: String, weight: Int) {
            let tokens = words(in: text)
            guard tokens.count > 1 else { return }
            for index in 1..<tokens.count where tokens[index - 1].lowercased() == previous {
                let strong = index > 1 && (earlier.map { tokens[index - 2].lowercased() == $0 } ?? false)
                let word = tokens[index]
                let key = word.lowercased()
                if let allowedWords, !allowedWords.contains(key) { continue }
                let points = weight * (strong ? 8 : 2)
                let old = scores[key]
                scores[key] = (old?.word ?? word, (old?.score ?? 0) + points)
            }
        }
        for item in items { accumulate(item.message, weight: 1) }
        for phrase in phrases where !phrase.text.contains("{") { accumulate(phrase.text, weight: 2) }
        for item in items {
            for phrase in item.phraseOptions ?? [] {
                accumulate(phrase.resolved(for: language).text, weight: 2)
            }
        }
        var historyIndex = 0
        for message in history where message.speaker != .partner {
            accumulate(message.text, weight: historyIndex < 10 ? 4 : 3)
            historyIndex += 1
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
