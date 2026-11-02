import Foundation

enum VocabularyStage: Int, Codable, CaseIterable, Hashable, Identifiable {
    case off = 0
    case start = 1
    case grow = 2
    case all = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: "Off · all words"
        case .start: "Start · essential words"
        case .grow: "Grow · more words"
        case .all: "All · full vocabulary"
        }
    }
}

enum ProgressiveVocabulary {
    private static let essential: [String: Set<String>] = [
        "Core": ["I", "want", "need", "yes", "no", "more", "stop", "go", "help", "please",
                 "you", "all done", "again", "different"],
        "Needs": ["water", "bathroom", "break", "pain", "medicine", "quiet", "space"],
        "Feelings": ["happy", "sad", "scared", "overwhelmed", "okay", "not okay"],
        "People": ["mom", "dad", "friend", "doctor"],
        "Food": ["eat", "drink", "snack", "water"],
        "Activities": ["play", "read", "music", "outside"],
        "Questions": ["what", "where", "who", "can I?"],
        "Sensory": ["too loud", "too bright", "no touch", "quiet room"],
        "Places": ["home", "school", "hospital"],
        "Time": ["now", "later", "wait"]
    ]

    static func isAvailable(_ item: CommunicationItem, stage: VocabularyStage,
                            exploring: Bool = false) -> Bool {
        guard item.boardVisibility != .hidden else { return false }
        if exploring || stage == .off || stage == .all { return true }
        if item.isCustom || item.isFavorite || item.imageData != nil || item.audioData != nil
            || item.effectiveAction != .addToMessage { return true }
        let starters = StarterVocabulary.items.filter { $0.category == item.category }
        guard let index = starters.firstIndex(where: { $0.label == item.label }) else { return true }
        if essential[item.category]?.contains(item.label) == true { return true }
        if stage == .start { return false }
        return index < Int((Double(starters.count) * 0.7).rounded(.up))
    }

    static func displayed(_ item: CommunicationItem, stage: VocabularyStage,
                          exploring: Bool = false) -> CommunicationItem {
        guard !isAvailable(item, stage: stage, exploring: exploring) else { return item }
        var copy = item
        copy.visibility = .hidden
        return copy
    }
}
