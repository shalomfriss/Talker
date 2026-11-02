import Foundation

struct WordKeyboardKey: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var text: String
    var spaceBefore: Bool = true
    var spaceAfter: Bool = true

    init(id: UUID = UUID(), label: String, text: String,
         spaceBefore: Bool = true, spaceAfter: Bool = true) {
        self.id = id
        self.label = label
        self.text = text
        self.spaceBefore = spaceBefore
        self.spaceAfter = spaceAfter
    }

    func inserting(into message: String, at cursorOffset: Int) -> (text: String, cursorOffset: Int) {
        let offset = min(max(0, cursorOffset), message.count)
        let split = message.index(message.startIndex, offsetBy: offset)
        var before = String(message[..<split])
        let after = String(message[split...])
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return (message, offset) }
        if !spaceBefore {
            while before.last == " " || before.last == "\t" {
                before.removeLast()
            }
        }
        let prefix = spaceBefore && !before.isEmpty && before.last?.isWhitespace != true ? " " : ""
        let suffix = spaceAfter && (after.isEmpty || (after.first?.isWhitespace != true
            && !",.!?;:".contains(after.first!))) ? " " : ""
        let insertion = prefix + content + suffix
        return (before + insertion + after, before.count + insertion.count)
    }

    static func starterKeys(language: String) -> [WordKeyboardKey] {
        language == "es" ? spanishStarterKeys : englishStarterKeys
    }

    private static let englishStarterKeys = makeStarterKeys(
        ["I", "want", "need", "help", "please", "yes", "no", "thank you"])
    private static let spanishStarterKeys = makeStarterKeys(
        ["Yo", "quiero", "necesito", "ayuda", "por favor", "sí", "no", "gracias"])

    private static func makeStarterKeys(_ words: [String]) -> [WordKeyboardKey] {
        return words.map { WordKeyboardKey(label: $0, text: $0) }
            + [WordKeyboardKey(label: ".", text: ".", spaceBefore: false),
               WordKeyboardKey(label: "?", text: "?", spaceBefore: false)]
    }

    static func cleaned(_ keys: [WordKeyboardKey]) -> [WordKeyboardKey] {
        var seen = Set<UUID>()
        return Array(keys.filter {
            !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.label.count <= 40 && $0.text.count <= 120
                && seen.insert($0.id).inserted
        }.prefix(40))
    }
}
