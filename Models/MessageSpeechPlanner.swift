import Foundation

struct MessageSpeechSegment: Equatable {
    let text: String
    let language: String
    let voiceIdentifier: String

    init(text: String, language: String, voiceIdentifier: String = "") {
        self.text = text
        self.language = language
        self.voiceIdentifier = voiceIdentifier
    }
}

enum MessageSpeechPlanner {
    static func segments(parts: [String], languages: [String], fallbackLanguage: String,
                         voiceIdentifiers: [String] = []) -> [MessageSpeechSegment] {
        var result: [MessageSpeechSegment] = []
        var runWords: [String] = []
        var runLanguage: String?
        var runVoiceIdentifier: String?
        for (index, rawText) in parts.enumerated() {
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let language = languages.indices.contains(index) ? languages[index] : fallbackLanguage
            let voiceIdentifier = voiceIdentifiers.indices.contains(index) ? voiceIdentifiers[index] : ""
            if let runLanguage, runLanguage != language || runVoiceIdentifier != voiceIdentifier {
                result.append(MessageSpeechSegment(text: runWords.joined(separator: " "), language: runLanguage,
                                                   voiceIdentifier: runVoiceIdentifier ?? ""))
                runWords.removeAll(keepingCapacity: true)
            }
            runLanguage = language
            runVoiceIdentifier = voiceIdentifier
            runWords.append(text)
        }
        if let runLanguage {
            result.append(MessageSpeechSegment(text: runWords.joined(separator: " "), language: runLanguage,
                                               voiceIdentifier: runVoiceIdentifier ?? ""))
        }
        return result
    }
}
