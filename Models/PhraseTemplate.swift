import Foundation

enum PhraseTemplate {
    private static let expression = try! NSRegularExpression(pattern: #"\{([\p{L}\p{N}][^{}]{0,39})\}"#)

    static func fields(in text: String) -> [String] {
        let source = text as NSString
        var seen = Set<String>()
        return matches(in: text).compactMap { match in
            let field = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !field.isEmpty, seen.insert(field).inserted else { return nil }
            return field
        }
    }

    static func render(_ text: String, values: [String: String]) -> String? {
        let source = text as NSString
        let result = NSMutableString(string: text)
        for match in matches(in: text).reversed() {
            let field = source.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = values[field]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            result.replaceCharacters(in: match.range, with: value)
        }
        return result as String
    }

    private static func matches(in text: String) -> [NSTextCheckingResult] {
        let source = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).filter { match in
            let before = match.range.location > 0
                ? source.substring(with: NSRange(location: match.range.location - 1, length: 1)) : ""
            let afterIndex = NSMaxRange(match.range)
            let after = afterIndex < source.length
                ? source.substring(with: NSRange(location: afterIndex, length: 1)) : ""
            return before != "{" && after != "}"
        }
    }
}
