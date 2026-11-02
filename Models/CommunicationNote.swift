import Foundation

struct CommunicationNote: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var topic: String
    var text: String
    var updatedAt: Date = .now
}
