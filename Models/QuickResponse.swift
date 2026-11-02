import Foundation

enum QuickResponseAction: String, Codable, CaseIterable, Identifiable {
    case addAndSpeak
    case speakOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addAndSpeak: "Add and speak"
        case .speakOnly: "Speak only"
        }
    }
}

struct QuickResponse: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var spanishText: String = ""
    var sourceWord: String? = nil
    var audioData: Data? = nil
    var action: QuickResponseAction = .addAndSpeak

    init(id: UUID = UUID(), text: String, spanishText: String = "", sourceWord: String? = nil,
         audioData: Data? = nil, action: QuickResponseAction = .addAndSpeak) {
        self.id = id
        self.text = text
        self.spanishText = spanishText
        self.sourceWord = sourceWord
        self.audioData = audioData
        self.action = action
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, spanishText, sourceWord, audioData, action
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try values.decode(String.self, forKey: .text)
        spanishText = try values.decodeIfPresent(String.self, forKey: .spanishText) ?? ""
        sourceWord = try values.decodeIfPresent(String.self, forKey: .sourceWord)
        audioData = try values.decodeIfPresent(Data.self, forKey: .audioData)
        action = try values.decodeIfPresent(QuickResponseAction.self, forKey: .action) ?? .addAndSpeak
    }

    static let maximumCount = 6
    static let maximumTextLength = 160

    static var starterReplies: [QuickResponse] {
        ["yes", "no", "help", "break"].map { word in
            QuickResponse(text: word, spanishText: StarterTranslations.spanish[word] ?? "",
                          sourceWord: word)
        }
    }

    func displayedText(language: String) -> String {
        language == "es" && !spanishText.isEmpty ? spanishText : text
    }

    static func cleaned(_ replies: [QuickResponse]) -> [QuickResponse] {
        var seen = Set<String>()
        return Array(replies.compactMap { reply -> QuickResponse? in
            var result = reply
            result.text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
            result.spanishText = reply.spanishText.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.sourceWord == nil,
               ["yes", "no", "help", "break"].contains(result.text),
               result.spanishText == StarterTranslations.spanish[result.text] {
                result.sourceWord = result.text
            }
            if let sourceWord = result.sourceWord,
               (result.text != sourceWord ||
                result.spanishText != StarterTranslations.spanish[sourceWord] ||
                !["yes", "no", "help", "break"].contains(sourceWord)) {
                result.sourceWord = nil
            }
            let key = result.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !key.isEmpty, result.text.count <= maximumTextLength,
                  result.spanishText.count <= maximumTextLength,
                  seen.insert(key).inserted else { return nil }
            return result
        }.prefix(maximumCount))
    }

    static func canSave(_ replies: [QuickResponse]) -> Bool {
        replies.count <= maximumCount && cleaned(replies).count == replies.count
    }
}
