import Foundation

enum SpokenChoiceText {
    static func cleaned(_ transcript: String) -> String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    static func adding(_ choice: String, to existing: String) -> String? {
        let label = cleaned(choice)
        let labels = QuickChoiceDraft(question: "", choices: existing).labels
        guard !label.isEmpty, labels.count < 8 else { return nil }
        let proposed = labels + [label]
        let unique = Set(proposed.map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        guard unique.count == proposed.count else { return nil }
        return proposed.joined(separator: "\n")
    }
}
