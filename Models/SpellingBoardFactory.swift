import Foundation

enum SpellingBoardLayout {
    case alphabetical
    case qwerty
}

enum SpellingBoardFactory {
    static func items(board: String, layout: SpellingBoardLayout = .alphabetical) -> [CommunicationItem] {
        let order: LetterOrder = layout == .qwerty ? .qwerty : .alphabetical
        let letters = order.letters(language: "es").map { letter in
            CommunicationItem(label: letter, symbol: letter, message: letter.lowercased(),
                              category: board, isCustom: true, action: .typeText)
        }
        let extraKeys: [CommunicationItem] = layout == .qwerty
            ? Array("1234567890,.?!").map { character in
                let text = String(character)
                return CommunicationItem(label: text, symbol: text, message: text,
                                         category: board, isCustom: true, action: .typeText)
            } : []
        let controls: [(String, String, ButtonAction)] = [
            ("Space", "␣", .typeSpace),
            ("Delete", "⌫", .deleteTypedCharacter),
            ("Left", "←", .moveTypedCursorLeft),
            ("Right", "→", .moveTypedCursorRight),
            ("Speak", "🗣️", .speakTypedMessage),
            ("Clear", "🧹", .clearTypedMessage),
            ("Full keyboard", "⌨️", .openKeyboard)
        ]
        let controlItems = controls.map { label, symbol, action in
            CommunicationItem(label: label, symbol: symbol, message: label,
                              category: board, isCustom: true, action: action)
        }
        let predictions = (0..<3).map { slot in
            CommunicationItem(label: "Suggestion \(slot + 1)", symbol: "✨", message: String(slot),
                              category: board, isCustom: true, action: .completeTypedPrediction)
        }
        return Array(controlItems.prefix(4)) + predictions + letters + extraKeys
            + Array(controlItems.dropFirst(4))
    }
}
