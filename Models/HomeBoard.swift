import Foundation

enum HomeBoard {
    static func resolved(_ preferred: String, categories: [String], hiddenBoards: [String]) -> String {
        let visible = categories.filter { !hiddenBoards.contains($0) }
        return visible.first { $0.localizedCaseInsensitiveCompare(preferred) == .orderedSame }
            ?? visible.first ?? "Core"
    }
}
