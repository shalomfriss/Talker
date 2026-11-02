import Foundation

struct CommunicationPassport: Codable, Equatable {
    var name = ""
    var introduction = ""
    var communicationMethods = ""
    var helpfulSupport = ""
    var boundaries = ""
    var whenOverwhelmed = ""
    var interests = ""

    var isEmpty: Bool { entries.isEmpty }

    var entries: [(title: String, value: String)] {
        [
            ("My name", name),
            ("About me", introduction),
            ("How I communicate", communicationMethods),
            ("What helps me communicate", helpfulSupport),
            ("Please respect", boundaries),
            ("When I feel overwhelmed", whenOverwhelmed),
            ("Things I like to talk about", interests)
        ].compactMap { title, value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : (title, clean)
        }
    }

    var shareText: String {
        entries.map { "\($0.title)\n\($0.value)" }.joined(separator: "\n\n")
    }
}
