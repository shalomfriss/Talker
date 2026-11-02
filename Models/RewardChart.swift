import Foundation

struct RewardChart: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var reward: String
    var symbol: String
    var targetTokens: Int
    var earnedTokens: Int
    var photoData: Data?

    var isComplete: Bool { earnedTokens == targetTokens }

    init(id: UUID = UUID(), title: String, reward: String, symbol: String = "⭐️",
         targetTokens: Int = 5, earnedTokens: Int = 0, photoData: Data? = nil) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reward = reward.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        self.symbol = cleanSymbol.isEmpty ? "⭐️" : String(cleanSymbol.prefix(4))
        self.targetTokens = min(20, max(1, targetTokens))
        self.earnedTokens = min(self.targetTokens, max(0, earnedTokens))
        self.photoData = photoData.flatMap { $0.count <= 4_000_000 ? $0 : nil }
    }

    var isValid: Bool {
        !title.isEmpty && title.count <= 100 && !reward.isEmpty && reward.count <= 100
    }

    @discardableResult
    mutating func setEarnedTokens(_ count: Int) -> Bool {
        guard (0...targetTokens).contains(count), count != earnedTokens else { return false }
        earnedTokens = count
        return true
    }

    @discardableResult
    mutating func startAgain() -> Bool {
        guard earnedTokens != 0 else { return false }
        earnedTokens = 0
        return true
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(UUID.self, forKey: .id),
                  title: try values.decode(String.self, forKey: .title),
                  reward: try values.decode(String.self, forKey: .reward),
                  symbol: try values.decodeIfPresent(String.self, forKey: .symbol) ?? "⭐️",
                  targetTokens: try values.decodeIfPresent(Int.self, forKey: .targetTokens) ?? 5,
                  earnedTokens: try values.decodeIfPresent(Int.self, forKey: .earnedTokens) ?? 0,
                  photoData: try values.decodeIfPresent(Data.self, forKey: .photoData))
    }
}
