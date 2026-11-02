import Compression
import Foundation

enum QRPageTransferError: LocalizedError {
    case boardUnavailable
    case unsupportedContent
    case tooLarge
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .boardUnavailable: "Choose a board to share."
        case .unsupportedContent: "This board has photos, recordings, videos, web links, linked boards, or multi-phrase buttons. Share its board file instead."
        case .tooLarge: "This page is too large for one QR code. Share its board file instead."
        case .invalidCode: "This is not a valid Open Voice page QR code."
        }
    }
}

struct QRPageTile: Codable, Equatable {
    let label: String
    let symbol: String
    let message: String
    let spanish: WordTranslation?
    let action: ButtonAction?
    let visibility: ButtonVisibility?
    let backgroundColorHex: String?
    let borderColorHex: String?
    let grammarCategory: GrammarCategory?

    private enum CodingKeys: String, CodingKey {
        case label = "l", symbol = "s", message = "m", spanish = "es"
        case action = "a", visibility = "v", backgroundColorHex = "bg"
        case borderColorHex = "bc", grammarCategory = "g"
    }
}

struct QRPageContent: Codable, Equatable {
    let version: Int
    let title: String
    let icon: String?
    let tiles: [QRPageTile]

    private enum CodingKeys: String, CodingKey {
        case version = "v", title = "n", icon = "i", tiles = "t"
    }
}

enum QRPageTransfer {
    static let prefix = "OVQR1:"
    static let maxCodeBytes = 2_500
    static let maxExpandedBytes = 100_000

    static func encode(title: String, icon: String?, items: [CommunicationItem],
                       translations: [String: [String: WordTranslation]]) throws -> String {
        guard !items.isEmpty, items.count <= 200 else { throw QRPageTransferError.tooLarge }
        guard items.allSatisfy({ $0.imageData == nil && $0.audioData == nil && $0.videoData == nil &&
                                 $0.videoPosterData == nil && $0.effectiveAction != .playVideo &&
                                 $0.effectiveAction != .openWebPage && $0.webURL == nil &&
                                 $0.effectiveAction != .openScene && $0.destinationSceneID == nil &&
                                 $0.destinationBoard == nil &&
                                 ($0.phraseOptions?.isEmpty ?? true) && !$0.effectiveAction.requiresDestination }) else {
            throw QRPageTransferError.unsupportedContent
        }
        let content = QRPageContent(version: 1, title: title, icon: icon,
                                    tiles: items.map { item in
            QRPageTile(label: item.label, symbol: item.symbol, message: item.message,
                       spanish: translations[item.id.uuidString]?["es"], action: item.action,
                       visibility: item.visibility, backgroundColorHex: item.backgroundColorHex,
                       borderColorHex: item.borderColorHex, grammarCategory: item.grammarCategory)
        })
        try validate(content)
        let raw = try JSONEncoder().encode(content)
        guard raw.count <= maxExpandedBytes else { throw QRPageTransferError.tooLarge }
        let compressed = try compress(raw)
        let encoded = compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let code = prefix + encoded
        guard code.utf8.count <= maxCodeBytes else { throw QRPageTransferError.tooLarge }
        return code
    }

    static func decode(_ text: String) throws -> QRPageContent {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix(prefix), clean.utf8.count <= maxCodeBytes,
              clean.utf8.count > prefix.utf8.count else { throw QRPageTransferError.invalidCode }
        let encoded = String(clean.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let compressed = Data(base64Encoded: padded), !compressed.isEmpty,
              let raw = decompress(compressed),
              let content = try? JSONDecoder().decode(QRPageContent.self, from: raw) else {
            throw QRPageTransferError.invalidCode
        }
        do { try validate(content) }
        catch { throw QRPageTransferError.invalidCode }
        return content
    }

    private static func validate(_ content: QRPageContent) throws {
        guard content.version == 1,
              (1...80).contains(content.title.count),
              content.title.trimmingCharacters(in: .whitespacesAndNewlines) == content.title,
              content.title.localizedCaseInsensitiveCompare("Favorites") != .orderedSame,
              content.icon.map({ (1...4).contains($0.count) }) ?? true,
              (1...200).contains(content.tiles.count) else { throw QRPageTransferError.invalidCode }
        for tile in content.tiles {
            guard (1...100).contains(tile.label.count), (1...8).contains(tile.symbol.count),
                  (1...500).contains(tile.message.count),
                  !tile.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !(tile.action?.requiresDestination ?? false),
                  tile.action != .playVideo,
                  tile.action != .openWebPage,
                  tile.action != .openScene,
                  tile.spanish.map({ (1...100).contains($0.label.count) && (1...500).contains($0.message.count) }) ?? true,
                  tile.backgroundColorHex.map({ ButtonColorValue(text: $0) != nil }) ?? true,
                  tile.borderColorHex.map({ ButtonColorValue(text: $0) != nil }) ?? true else {
                throw QRPageTransferError.invalidCode
            }
        }
    }

    private static func compress(_ data: Data) throws -> Data {
        var output = [UInt8](repeating: 0, count: data.count + 256)
        let size = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_encode_buffer(destination.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                          destination.count,
                                          source.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                          source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard size > 0 else { throw QRPageTransferError.tooLarge }
        return Data(output.prefix(size))
    }

    private static func decompress(_ data: Data) -> Data? {
        var output = [UInt8](repeating: 0, count: maxExpandedBytes + 1)
        let size = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_decode_buffer(destination.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                          destination.count,
                                          source.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                          source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard size > 0, size <= maxExpandedBytes else { return nil }
        return Data(output.prefix(size))
    }
}
