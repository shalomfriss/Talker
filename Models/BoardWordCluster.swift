struct BoardWordCluster: Identifiable, Equatable {
    let id: Int
    let startIndex: Int
    let items: [CommunicationItem]

    var rangeLabel: String { "Buttons \(startIndex + 1)–\(startIndex + items.count)" }

    static func groups(for items: [CommunicationItem], count: Int = 6) -> [Self] {
        guard !items.isEmpty else { return [] }
        let groupCount = min(max(1, count), items.count)
        let smallest = items.count / groupCount
        let extra = items.count % groupCount
        var start = 0
        return (0..<groupCount).map { index in
            let size = smallest + (index < extra ? 1 : 0)
            defer { start += size }
            return Self(id: index, startIndex: start, items: Array(items[start..<(start + size)]))
        }
    }
}
