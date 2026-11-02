import Foundation

enum GrammarColorScheme: String, Codable, CaseIterable, Identifiable {
    case board
    case fitzgeraldBorder
    case fitzgeraldFill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .board: "Board colors"
        case .fitzgeraldBorder: "Grammar borders"
        case .fitzgeraldFill: "Grammar backgrounds"
        }
    }
}

enum GrammarCategory: String, Codable, CaseIterable, Identifiable {
    case people
    case verbs
    case littleWords
    case describing
    case things
    case places
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .people: "People and pronouns"
        case .verbs: "Actions and verbs"
        case .littleWords: "Little and question words"
        case .describing: "Describing and time words"
        case .things: "Things"
        case .places: "Places"
        case .social: "Social words and phrases"
        }
    }

    // Soft fills keep black labels readable; saturated borders remain distinct.
    var fillHex: String {
        switch self {
        case .people: "#FFF0B3"
        case .verbs: "#D8F2D1"
        case .littleWords: "#FAD9E8"
        case .describing: "#DCEBFF"
        case .things: "#FFE2C4"
        case .places: "#E9DEFA"
        case .social: "#ECECEC"
        }
    }

    var borderHex: String {
        switch self {
        case .people: "#A87500"
        case .verbs: "#257A32"
        case .littleWords: "#A52366"
        case .describing: "#2461A6"
        case .things: "#A45614"
        case .places: "#6840A4"
        case .social: "#5B5B5B"
        }
    }

    static func starter(category: String, label: String) -> GrammarCategory? {
        switch category {
        case "Core":
            if ["I", "you", "it", "that", "my", "your"].contains(label) { return .people }
            if ["want", "need", "like", "do", "stop", "go", "help"].contains(label) { return .verbs }
            if ["don't", "not", "here", "there"].contains(label) { return .littleWords }
            if ["more", "different"].contains(label) { return .describing }
            return .social
        case "Needs":
            if ["rest", "sleep", "call home"].contains(label) { return .verbs }
            if ["hungry", "thirsty", "too hot", "too cold", "quiet"].contains(label) { return .describing }
            if label == "space" { return .places }
            return .things
        case "Feelings", "Time": return .describing
        case "People": return .people
        case "Food": return ["eat", "drink"].contains(label) ? .verbs : .things
        case "Activities":
            return ["play", "read", "draw", "walk", "watch", "listen", "learn", "work", "swim"].contains(label)
                ? .verbs : .things
        case "Questions": return .littleWords
        case "Sensory":
            return ["too loud", "too bright"].contains(label) ? .describing : .things
        case "Places": return .places
        default: return nil
        }
    }
}

enum GrammarColorCoding {
    static func category(for item: CommunicationItem) -> GrammarCategory? {
        if let grammarCategory = item.grammarCategory { return grammarCategory }
        guard !item.isCustom else { return nil }
        return GrammarCategory.starter(category: item.category, label: item.label)
    }

    static func colors(for item: CommunicationItem, scheme: GrammarColorScheme)
        -> (background: String?, border: String?) {
        guard scheme != .board, let category = category(for: item) else { return (nil, nil) }
        switch scheme {
        case .board: return (nil, nil)
        case .fitzgeraldBorder: return (nil, category.borderHex)
        case .fitzgeraldFill: return (category.fillHex, category.borderHex)
        }
    }
}
