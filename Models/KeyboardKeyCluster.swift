struct KeyboardKeyCluster: Identifiable, Equatable {
    let id: Int
    let keys: [String]

    static func groups(for keys: [String], count: Int = 6) -> [Self] {
        guard !keys.isEmpty else { return [] }
        let groupCount = min(max(1, count), keys.count)
        let smallest = keys.count / groupCount
        let extra = keys.count % groupCount
        var start = 0
        return (0..<groupCount).map { index in
            let size = smallest + (index < extra ? 1 : 0)
            defer { start += size }
            return Self(id: index, keys: Array(keys[start..<(start + size)]))
        }
    }
}
