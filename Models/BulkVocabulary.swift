import Foundation

struct BulkVocabularyEntry: Equatable {
    let label: String
    let symbol: String
    let message: String
}

struct BulkVocabularyPreview {
    let entries: [BulkVocabularyEntry]
    let existingCount: Int
    let repeatedCount: Int
    let invalidCount: Int
    let exceedsLimit: Bool
    let inputTooLong: Bool

    var canAdd: Bool { !entries.isEmpty && !exceedsLimit && !inputTooLong }
}

enum BulkVocabulary {
    static let maximumEntries = 1_000
    static let maximumInputCharacters = 100_000

    static func editableList(from transcript: String) -> String {
        transcript
            .replacingOccurrences(of: "\\s*(?:,|;|\\bnext button\\b)\\s*", with: "\n",
                                  options: [.regularExpression, .caseInsensitive])
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func key(for label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func preview(_ input: String, board: String,
                        existing: [CommunicationItem]) -> BulkVocabularyPreview {
        guard input.count <= maximumInputCharacters else {
            return BulkVocabularyPreview(entries: [], existingCount: 0, repeatedCount: 0,
                                         invalidCount: 0, exceedsLimit: false, inputTooLong: true)
        }
        let onBoard = Set(existing.filter { $0.category == board }.map { key(for: $0.label) })
        var symbols: [String: String] = [:]
        for item in StarterVocabulary.items + existing where !item.symbol.isEmpty {
            symbols[key(for: item.label)] = item.symbol
        }
        var seen = Set<String>()
        var entries: [BulkVocabularyEntry] = []
        var existingCount = 0
        var repeatedCount = 0
        var invalidCount = 0
        var exceedsLimit = false

        for line in input.components(separatedBy: .newlines) {
            let parts = line.contains("|") ? [line] : line.components(separatedBy: ",")
            for part in parts {
                let fields = part.split(separator: "|", maxSplits: 2,
                                        omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let label = fields.first ?? ""
                if label.isEmpty {
                    if fields.count > 1 { invalidCount += 1 }
                    continue
                }
                let symbol = fields.count > 1 && !fields[1].isEmpty
                    ? fields[1] : (symbols[key(for: label)] ?? "💬")
                let message = fields.count > 2 && !fields[2].isEmpty ? fields[2] : label
                guard label.count <= 80, symbol.count <= 8, message.count <= 400 else {
                    invalidCount += 1
                    continue
                }
                let key = key(for: label)
                if onBoard.contains(key) { existingCount += 1; continue }
                if !seen.insert(key).inserted { repeatedCount += 1; continue }
                if entries.count >= maximumEntries { exceedsLimit = true; continue }
                entries.append(BulkVocabularyEntry(label: label, symbol: symbol, message: message))
            }
        }
        return BulkVocabularyPreview(entries: entries, existingCount: existingCount,
                                     repeatedCount: repeatedCount, invalidCount: invalidCount,
                                     exceedsLimit: exceedsLimit, inputTooLong: false)
    }
}
