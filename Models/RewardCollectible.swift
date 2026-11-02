import Foundation

struct RewardCollectible: Codable, Identifiable, Equatable {
    let id: UUID
    let chartID: UUID
    let chartTitle: String
    let reward: String
    let symbol: String
    let photoData: Data?
    let collectedAt: Date

    init(chart: RewardChart, collectedAt: Date = .now) {
        id = UUID()
        chartID = chart.id
        chartTitle = chart.title
        reward = chart.reward
        symbol = chart.symbol
        photoData = chart.photoData
        self.collectedAt = collectedAt
    }
}
