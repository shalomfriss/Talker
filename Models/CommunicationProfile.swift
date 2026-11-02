import Foundation

struct CommunicationProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var fileName: String
}

struct ProfileDirectory: Codable {
    var profiles: [CommunicationProfile]
    var activeProfileID: UUID
}
