import Foundation

struct PronunciationRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var written: String
    var spoken: String
    var language: String
}

enum PronunciationDictionary {
    static func cleaned(_ rule: PronunciationRule, existing: [PronunciationRule]) -> PronunciationRule? {
        var result = rule
        result.written = rule.written.trimmingCharacters(in: .whitespacesAndNewlines)
        result.spoken = rule.spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(result.written.count), (1...120).contains(result.spoken.count),
              !result.written.contains(where: \.isNewline), !result.spoken.contains(where: \.isNewline),
              ["en", "es"].contains(result.language),
              !existing.contains(where: {
                  $0.id != result.id && $0.language == result.language
                      && $0.written.compare(result.written, options: .caseInsensitive) == .orderedSame
              }) else { return nil }
        return result
    }

    static func applying(_ text: String, language: String, rules: [PronunciationRule]) -> String {
        let relevant = Array(rules.filter {
            $0.language == language && !$0.written.isEmpty && !$0.spoken.isEmpty
        }.prefix(100))
        guard !relevant.isEmpty else { return text }
        let alternatives = relevant.sorted { $0.written.count > $1.written.count }
            .map { NSRegularExpression.escapedPattern(for: $0.written) }
            .joined(separator: "|")
        let pattern = "(?<![\\p{L}\\p{N}\\p{M}])(?:\(alternatives))(?![\\p{L}\\p{N}\\p{M}])"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        guard !matches.isEmpty else { return text }
        var output = ""
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            output.append(contentsOf: text[cursor..<range.lowerBound])
            let found = String(text[range])
            output += relevant.first {
                $0.written.compare(found, options: .caseInsensitive) == .orderedSame
            }?.spoken ?? found
            cursor = range.upperBound
        }
        output.append(contentsOf: text[cursor...])
        return output
    }
}
