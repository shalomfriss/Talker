import Foundation

struct FeelingLogEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var feelingLabel: String
    var symbol: String
    var intensity: Int
    var support: String?
    var message: String
    var language: String
    var scaleMaximum: Int? = nil
}
