import Foundation

enum LanguageSampleTranscript {
    static func renderCSV(entries: [SpokenMessage], profileName: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let profile = csvField(clean(profileName))
        var lines = ["timestamp_utc,profile,speaker,input_mode,message"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([
                csvField(formatter.string(from: entry.date)),
                profile,
                csvField(entry.speaker?.title ?? "Speaker not recorded"),
                csvField(entry.inputMode?.title ?? "Input not recorded"),
                csvField(entry.text)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func render(entries: [SpokenMessage], profileName: String,
                       timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        let name = clean(profileName)
        var lines = [
            "Open Voice language sample",
            "Profile: \(name)",
            "Saved entries: \(entries.count)",
            "This transcript includes only opt-in saved entries (at most 50). Partner turns are manually entered. Review speaker and input labels before using it as a record.",
            ""
        ]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let speaker = entry.speaker?.title ?? "Speaker not recorded"
            let input = entry.inputMode?.title ?? "Input not recorded"
            lines.append("[\(formatter.string(from: entry.date))] \(speaker) (\(input)): \(clean(entry.text))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func clean(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func csvField(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        let startsFormula = text.first(where: { !$0.isWhitespace }).map { "=+-@".contains($0) } ?? false
        return "\"\(startsFormula ? "'" : "")\(escaped)\""
    }
}
