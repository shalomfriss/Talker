import Foundation

struct NearbyChatToken: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let symbol: String?
    let imageData: Data?

    init(id: UUID = UUID(), text: String, symbol: String? = nil, imageData: Data? = nil) {
        self.id = id
        self.text = text
        self.symbol = symbol
        self.imageData = imageData
    }

    static func prepared(from token: PictureMessageToken) async -> NearbyChatToken {
        let imageData: Data?
        if let data = token.imageData {
            imageData = await PhotoProcessing.preparedDataAsync(from: data, maxPixelSize: 128,
                                                                 jpegQuality: 0.65)
        } else {
            imageData = nil
        }
        return NearbyChatToken(text: token.text, symbol: token.symbol, imageData: imageData)
    }
}

struct NearbyChatMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let peerName: String
    let recipientName: String?
    let isMine: Bool
    let text: String
    let tokens: [NearbyChatToken]

    init(id: UUID = UUID(), date: Date = .now, peerName: String, recipientName: String? = nil, isMine: Bool,
         text: String, tokens: [NearbyChatToken] = []) {
        self.id = id
        self.date = date
        self.peerName = peerName
        self.recipientName = recipientName
        self.isMine = isMine
        self.text = text
        self.tokens = tokens
    }
}

struct NearbyChatPacket: Codable, Sendable {
    let version: Int
    let id: UUID
    let date: Date
    let text: String
    let tokens: [NearbyChatToken]

    init(message: NearbyChatMessage) {
        version = 1
        id = message.id
        date = message.date
        text = message.text
        tokens = message.tokens
    }

    func encoded() throws -> Data {
        guard isValid else { throw NearbyChatError.invalidMessage }
        let data = try JSONEncoder().encode(self)
        guard data.count <= 2_000_000 else { throw NearbyChatError.messageTooLarge }
        return data
    }

    func encodedAsync() async throws -> Data {
        try await Task.detached(priority: .userInitiated) { @Sendable in
            try encoded()
        }.value
    }

    static func decode(_ data: Data) throws -> NearbyChatPacket {
        guard data.count <= 2_000_000 else { throw NearbyChatError.messageTooLarge }
        let packet = try JSONDecoder().decode(Self.self, from: data)
        guard packet.isValid else { throw NearbyChatError.invalidMessage }
        return packet
    }

    private var isValid: Bool {
        version == 1 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count <= 4_000 && tokens.count <= 100
            && tokens.allSatisfy { $0.text.count <= 200 && ($0.symbol?.count ?? 0) <= 20
                && ($0.imageData?.count ?? 0) <= 100_000 }
    }
}

enum NearbyChatError: LocalizedError, Equatable {
    case noConnection
    case invalidMessage
    case messageTooLarge

    var errorDescription: String? {
        switch self {
        case .noConnection: "Connect to a nearby device first."
        case .invalidMessage: "This message cannot be sent."
        case .messageTooLarge: "This message has too many pictures to send."
        }
    }
}
