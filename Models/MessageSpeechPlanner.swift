import Foundation

struct MessageSpeechSegment: Equatable {
    let text: String
    let language: String
}

enum MessageSpeechPlanner {
    static func segments(parts: [String], languages: [String], fallbackLanguage: String) -> [MessageSpeechSegment] {
        var result: [MessageSpeechSegment] = []
        for (index, rawText) in parts.enumerated() {
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let language = languages.indices.contains(index) ? languages[index] : fallbackLanguage
            if let last = result.last, last.language == language {
                result[result.count - 1] = MessageSpeechSegment(text: last.text + " " + text, language: language)
            } else {
                result.append(MessageSpeechSegment(text: text, language: language))
            }
        }
        return result
    }
}
