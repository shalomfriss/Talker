import Foundation

enum PhraseCollectionTransferError: LocalizedError {
    case tooLarge
    case unsupportedFormat
    case invalidCollection

    var errorDescription: String? {
        switch self {
        case .tooLarge: "This phrase file is too large. The limit is 128 MB."
        case .unsupportedFormat: "This is not a supported Open Voice phrase file."
        case .invalidCollection: "This phrase file contains no usable phrases or has invalid phrase details."
        }
    }
}

struct PhraseCollectionTransfer: Codable {
    static let maxImportBytes = 128 * 1_048_576
    static let maxPhrases = 5_000
    private static let formatName = "org.openvoice.phrase-collection"

    let format: String
    let version: Int
    let name: String
    let phrases: [SavedPhrase]

    static func exportData(_ phrases: [SavedPhrase], named name: String) throws -> Data {
        guard !phrases.isEmpty, phrases.count <= maxPhrases else {
            throw PhraseCollectionTransferError.invalidCollection
        }
        let collection = Self(format: formatName, version: 1, name: name, phrases: phrases)
        let data = try JSONEncoder().encode(collection)
        guard data.count <= maxImportBytes else { throw PhraseCollectionTransferError.tooLarge }
        return data
    }

    static func importData(_ data: Data) throws -> Self {
        guard data.count <= maxImportBytes else { throw PhraseCollectionTransferError.tooLarge }
        let collection: Self
        do { collection = try JSONDecoder().decode(Self.self, from: data) }
        catch { throw PhraseCollectionTransferError.unsupportedFormat }
        guard collection.format == formatName, collection.version == 1 else {
            throw PhraseCollectionTransferError.unsupportedFormat
        }
        guard (1...maxPhrases).contains(collection.phrases.count),
              collection.phrases.allSatisfy({ phrase in
                  !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      && (phrase.label?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) <= 40
                      && (phrase.shortcut == nil || PhraseShortcut.normalized(phrase.shortcut) != nil)
                      && (phrase.imageData?.count ?? 0) <= 8 * 1_048_576
                      && (phrase.audioData?.count ?? 0) <= 20 * 1_048_576
              }) else { throw PhraseCollectionTransferError.invalidCollection }
        return collection
    }

    func counts(against existing: [SavedPhrase]) -> (new: Int, matching: Int, repeated: Int) {
        let existingKeys = Set(existing.map { Self.key(for: $0.text) })
        var seen = Set<String>()
        var new = 0
        var matching = 0
        var repeated = 0
        for phrase in phrases {
            let key = Self.key(for: phrase.text)
            guard seen.insert(key).inserted else { repeated += 1; continue }
            if existingKeys.contains(key) { matching += 1 }
            else { new += 1 }
        }
        return (new, matching, repeated)
    }

    static func key(for text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

enum PhraseCollectionMergeMode {
    case addMissing
    case updateMatching
}

struct PhraseCollectionImportResult {
    let added: Int
    let updated: Int
    let skipped: Int
    let clearedShortcuts: Int
    let omittedPictures: Int
    let omittedRecordings: Int
}
