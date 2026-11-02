import Foundation

enum PhraseShortcut {
    static func normalized(_ input: String?) -> String? {
        guard let input else { return nil }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        guard (2...12).contains(value.count), value.unicodeScalars.allSatisfy({
            ("a"..."z").contains(String($0)) || ("0"..."9").contains(String($0))
        }) else { return nil }
        return value
    }

    static func trailingToken(in message: String) -> String? {
        guard let range = message.range(of: "[A-Za-z0-9]+$", options: .regularExpression) else { return nil }
        return String(message[range]).lowercased()
    }

    static func matches(_ message: String, phrases: [SavedPhrase]) -> [SavedPhrase] {
        guard let token = trailingToken(in: message) else { return [] }
        return Array(phrases.filter { $0.shortcut?.hasPrefix(token) == true }.prefix(5))
    }

    static func expanding(_ message: String, with phrase: String) -> String {
        guard let range = message.range(of: "[A-Za-z0-9]+$", options: .regularExpression) else { return message }
        var result = message
        result.replaceSubrange(range, with: phrase)
        return result + " "
    }
}
