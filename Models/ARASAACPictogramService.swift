import Foundation

struct ARASAACPictogram: Decodable, Identifiable {
    struct Keyword: Decodable {
        let keyword: String?
    }

    let id: Int
    let keywords: [Keyword]

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case keywords
    }

    var title: String {
        keywords.compactMap(\.keyword).first(where: { !$0.isEmpty }) ?? "Pictogram \(id)"
    }

    var previewURL: URL? { ARASAACPictogramService.imageURL(id: id, size: 300) }
}

enum ARASAACPictogramError: LocalizedError {
    case invalidQuery
    case serviceUnavailable
    case responseTooLarge
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .invalidQuery: "Enter a word or short phrase to search."
        case .serviceUnavailable: "ARASAAC is unavailable. Check your connection and try again."
        case .responseTooLarge: "The pictogram response was too large."
        case .unreadableImage: "This pictogram could not be opened."
        }
    }
}

@MainActor
enum ARASAACPictogramService {
    nonisolated static let termsURL = URL(string: "https://arasaac.org/terms-of-use")!
    nonisolated static let attribution = "Pictograms: Sergio Palao · ARASAAC (arasaac.org) · Government of Aragón · CC BY-NC-SA"

    static func searchURL(query: String, language: String) -> URL? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 80, ["en", "es"].contains(language),
              let encoded = clean.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))
        else { return nil }
        return URL(string: "https://api.arasaac.org/v1/pictograms/\(language)/search/\(encoded)")
    }

    nonisolated static func imageURL(id: Int, size: Int) -> URL? {
        guard (1...10_000_000).contains(id), [300, 500].contains(size) else { return nil }
        return URL(string: "https://static.arasaac.org/pictograms/\(id)/\(id)_\(size).png")
    }

    static func search(query: String, language: String) async throws -> [ARASAACPictogram] {
        guard let url = searchURL(query: query, language: language) else {
            throw ARASAACPictogramError.invalidQuery
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ARASAACPictogramError.serviceUnavailable
        }
        guard data.count <= 2 * 1_048_576 else { throw ARASAACPictogramError.responseTooLarge }
        return Array(try JSONDecoder().decode([ARASAACPictogram].self, from: data)
            .filter { imageURL(id: $0.id, size: 300) != nil }
            .prefix(48))
    }

    static func download(id: Int) async throws -> Data {
        guard let url = imageURL(id: id, size: 500) else {
            throw ARASAACPictogramError.unreadableImage
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ARASAACPictogramError.serviceUnavailable
        }
        guard data.count <= 5 * 1_048_576 else { throw ARASAACPictogramError.responseTooLarge }
        guard let prepared = PhotoProcessing.preparedData(from: data) else {
            throw ARASAACPictogramError.unreadableImage
        }
        return prepared
    }
}
