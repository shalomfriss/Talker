import Foundation

struct LearnedPredictionEntry: Codable, Equatable {
    var language: String
    var context: [String]
    var word: String
    var count: Int
    var lastSeen: Int
}

struct LearnedPredictionModel: Codable, Equatable {
    private struct EntryKey: Hashable {
        var language: String
        var context: [String]
        var word: String
    }

    private(set) var entries: [LearnedPredictionEntry] = []
    private(set) var generation = 0

    private static let wordExpression = try? NSRegularExpression(pattern: #"\p{L}[\p{L}\p{M}'’-]*"#)
    private static let maximumEntries = 1_800
    private static let sentenceStart = "<sentence-start>"
    private static let sentenceEnd = "<sentence-end>"

    mutating func learn(_ text: String, language: String) {
        guard !text.isEmpty, text.count <= 500 else { return }
        generation += 1
        var entryIndices: [EntryKey: Int] = [:]
        entryIndices.reserveCapacity(entries.count)
        for (index, entry) in entries.enumerated() {
            let key = EntryKey(language: entry.language, context: entry.context,
                               word: Self.key(entry.word, language: entry.language))
            if entryIndices[key] == nil { entryIndices[key] = index }
        }
        for segment in text.split(whereSeparator: { ".?!;\n".contains($0) }) {
            let tokens = Self.words(in: String(segment)).filter { $0.count <= 24 }
            guard !tokens.isEmpty, tokens.count <= 100 else { continue }
            for index in tokens.indices {
                let word = tokens[index]
                var contexts: [[String]] = [[]]
                if index == 0 { contexts.append([Self.sentenceStart]) }
                if index > 0 { contexts.append([Self.key(tokens[index - 1], language: language)]) }
                if index == 1 {
                    contexts.append([Self.sentenceStart, Self.key(tokens[0], language: language)])
                }
                if index > 1 {
                    contexts.append([Self.key(tokens[index - 2], language: language),
                                     Self.key(tokens[index - 1], language: language)])
                }
                for context in contexts {
                    record(word, after: context, language: language, entryIndices: &entryIndices)
                }
            }
            let endContext = tokens.suffix(2).map { Self.key($0, language: language) }
            record(Self.sentenceEnd, after: endContext, language: language, entryIndices: &entryIndices)
        }
        if entries.count > Self.maximumEntries {
            entries.sort {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.lastSeen > $1.lastSeen
            }
            entries = Array(entries.prefix(Self.maximumEntries))
        }
    }

    func suggestions(for text: String, language: String, limit: Int,
                     allowedWords: Set<String>? = nil) -> [String] {
        guard limit > 0 else { return [] }
        let activeRange = text.range(of: #"\p{L}[\p{L}\p{M}'’-]*$"#, options: .regularExpression)
        let prefix = activeRange.map { Self.key(String(text[$0]), language: language) }
        if prefix == nil {
            guard text.last?.isWhitespace == true else { return [] }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let last = trimmed.last, !".?!;".contains(last) else { return [] }
        }
        let contextText = activeRange.map { String(text[..<$0.lowerBound]) } ?? text
        let previous = Self.words(in: contextText).suffix(2).map { Self.key($0, language: language) }
        guard prefix != nil || !previous.isEmpty else { return [] }
        var scores: [String: (word: String, score: Int, lastSeen: Int)] = [:]
        for entry in entries where entry.language == language && entry.count >= 2
            && entry.word != Self.sentenceEnd {
            guard entry.context.count <= previous.count,
                  Array(previous.suffix(entry.context.count)) == entry.context else { continue }
            if prefix == nil && entry.context.isEmpty { continue }
            let wordKey = Self.key(entry.word, language: language)
            if let prefix, (!wordKey.hasPrefix(prefix) || wordKey == prefix) { continue }
            if let allowedWords, !allowedWords.contains(entry.word.lowercased()) { continue }
            let multiplier = entry.context.count == 2 ? 9 : (entry.context.count == 1 ? 3 : 1)
            let old = scores[wordKey]
            scores[wordKey] = (entry.word, (old?.score ?? 0) + entry.count * multiplier,
                               max(old?.lastSeen ?? 0, entry.lastSeen))
        }
        return scores.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.lastSeen != $1.lastSeen { return $0.lastSeen > $1.lastSeen }
            return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
        }
        .prefix(limit)
        .map(\.word)
    }

    func sentenceCompletions(for prefix: String, language: String, limit: Int) -> [String] {
        let typed = Self.words(in: prefix)
        guard limit > 0, !typed.isEmpty, typed.count <= 12 else { return [] }
        let trailingSpace = prefix.last?.isWhitespace == true
        let optionsByContext = Dictionary(grouping: entries.filter {
            $0.language == language && $0.count >= 2
        }, by: \.context).mapValues { options in
            options.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.lastSeen > $1.lastSeen
            }
        }
        struct State {
            var words: [String]
            var score: Int
            var lastSeen: Int
        }
        var frontier = [State(words: [], score: 0, lastSeen: 0)]
        var results: [State] = []
        for _ in 0..<12 {
            var next: [State] = []
            for state in frontier {
                let context: [String]
                if state.words.isEmpty {
                    context = [Self.sentenceStart]
                } else if state.words.count == 1 {
                    context = [Self.sentenceStart, Self.key(state.words[0], language: language)]
                } else {
                    context = state.words.suffix(2).map { Self.key($0, language: language) }
                }
                let options = optionsByContext[context] ?? []
                for option in options.prefix(4) {
                    if option.word == Self.sentenceEnd {
                        if state.words.count >= max(2, typed.count) { results.append(state) }
                        continue
                    }
                    let position = state.words.count
                    if position < typed.count {
                        let expected = Self.key(typed[position], language: language)
                        let actual = Self.key(option.word, language: language)
                        if position < typed.count - 1 || trailingSpace {
                            guard actual == expected else { continue }
                        } else {
                            guard actual.hasPrefix(expected) else { continue }
                        }
                    }
                    next.append(State(words: state.words + [option.word],
                                      score: state.score + option.count,
                                      lastSeen: max(state.lastSeen, option.lastSeen)))
                }
            }
            frontier = Array(next.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.lastSeen > $1.lastSeen
            }.prefix(12))
            if frontier.isEmpty { break }
        }
        var seen = Set<String>()
        return results.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.lastSeen > $1.lastSeen
        }.map { $0.words.joined(separator: " ") }
            .filter { seen.insert(Self.key($0, language: language)).inserted }
            .prefix(limit)
            .map { $0 }
    }

    mutating func clear() {
        entries.removeAll()
        generation = 0
    }

    private mutating func record(_ word: String, after context: [String], language: String,
                                 entryIndices: inout [EntryKey: Int]) {
        let key = EntryKey(language: language, context: context, word: Self.key(word, language: language))
        if let existing = entryIndices[key] {
            entries[existing].count = min(1_000, entries[existing].count + 1)
            entries[existing].lastSeen = generation
        } else {
            entryIndices[key] = entries.count
            entries.append(LearnedPredictionEntry(language: language, context: context,
                                                  word: word, count: 1, lastSeen: generation))
        }
    }

    private static func words(in text: String) -> [String] {
        guard let wordExpression else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return wordExpression.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static func key(_ word: String, language: String) -> String {
        word.lowercased(with: Locale(identifier: language == "es" ? "es_ES" : "en_US"))
    }
}
