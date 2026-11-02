import Foundation

struct BoardWordFinderResult: Identifiable, Equatable {
    let item: CommunicationItem
    let displayLabel: String

    var id: UUID { item.id }

    var path: [String] {
        item.category == "Core" ? ["Core", displayLabel] : ["Core", item.category, displayLabel]
    }
}

enum BoardWordFinder {
    static func matches(_ query: String, in items: [CommunicationItem],
                        dimmedButtonsActive: Bool = true,
                        labelFor: (CommunicationItem) -> String) -> [BoardWordFinderResult] {
        let term = key(query)
        guard !term.isEmpty else { return [] }
        return items.compactMap { item -> (result: BoardWordFinderResult, rank: Int)? in
            guard item.isBoardSelectable(dimmedButtonsActive: dimmedButtonsActive) else { return nil }
            let label = labelFor(item)
            let shown = key(label)
            let original = key(item.label)
            let spoken = key(item.message)
            let rank: Int
            if shown == term || original == term { rank = 0 }
            else if shown.hasPrefix(term) || original.hasPrefix(term) { rank = 1 }
            else if shown.contains(term) || original.contains(term) { rank = 2 }
            else if spoken.contains(term) { rank = 3 }
            else { return nil }
            return (BoardWordFinderResult(item: item, displayLabel: label), rank)
        }
        .sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            if $0.result.item.category != $1.result.item.category {
                return $0.result.item.category.localizedStandardCompare($1.result.item.category) == .orderedAscending
            }
            return $0.result.displayLabel.localizedStandardCompare($1.result.displayLabel) == .orderedAscending
        }
        .prefix(60)
        .map(\.result)
    }

    private static func key(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
