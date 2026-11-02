import Foundation
import PDFKit
import UIKit

enum ReadAloudDocumentError: LocalizedError {
    case unsupportedFile
    case unreadableFile
    case noReadableText
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFile: "Choose a PDF, text file, or page image."
        case .unreadableFile: "This file could not be opened."
        case .noReadableText: "No readable text was found. Try a clearer page photo or type the text."
        case .fileTooLarge: "Choose a file smaller than 40 MB."
        }
    }
}

struct ReadAloudDocument: Sendable {
    var title: String
    var pages: [String]

    static func imported(data: Data, fileName: String) throws -> Self {
        guard data.count <= 40_000_000 else { throw ReadAloudDocumentError.fileTooLarge }
        let title = (fileName as NSString).deletingPathExtension
        let fileType = (fileName as NSString).pathExtension.lowercased()
        switch fileType {
        case "pdf":
            guard let pdf = PDFDocument(data: data), pdf.pageCount > 0 else {
                throw ReadAloudDocumentError.unreadableFile
            }
            let pages = (0..<pdf.pageCount).map { index in
                guard let page = pdf.page(at: index) else { return "" }
                let selectable = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !selectable.isEmpty { return selectable }
                guard let imageData = page.thumbnail(of: CGSize(width: 1600, height: 2000),
                                                     for: .mediaBox).pngData() else { return "" }
                return (try? DrawingTextRecognition.recognize(imageData: imageData)) ?? ""
            }
            guard pages.contains(where: { !$0.isEmpty }) else { throw ReadAloudDocumentError.noReadableText }
            return Self(title: title, pages: pages)
        case "txt", "text":
            guard let value = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16)
                    ?? String(data: data, encoding: .utf16LittleEndian)
                    ?? String(data: data, encoding: .utf16BigEndian) else {
                throw ReadAloudDocumentError.unreadableFile
            }
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw ReadAloudDocumentError.noReadableText }
            return Self(title: title, pages: [text])
        case "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff":
            let text = try DrawingTextRecognition.recognize(imageData: data)
            return Self(title: title, pages: [text])
        default:
            throw ReadAloudDocumentError.unsupportedFile
        }
    }
}

enum ReadingLibraryError: LocalizedError, Equatable {
    case emptyTitle
    case emptyText
    case documentTooLong
    case libraryFull

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Give this reading a title."
        case .emptyText: "Add some text before saving."
        case .documentTooLong: "This reading is too long to save. You can still read it now."
        case .libraryFull: "The saved reading library is full. Delete an older reading to make room."
        }
    }
}

struct SavedReadingDocument: Codable, Identifiable, Equatable {
    static let maximumDocuments = 100
    static let maximumDocumentCharacters = 500_000
    static let maximumLibraryCharacters = 3_000_000

    var id: UUID
    var title: String
    var pages: [String]
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, pages: [String], updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.pages = pages
        self.updatedAt = updatedAt
    }

    var characterCount: Int { pages.reduce(0) { $0 + $1.count } }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        characterCount <= Self.maximumDocumentCharacters
    }

    var readingDocument: ReadAloudDocument { ReadAloudDocument(title: title, pages: pages) }

    static func cleaned(_ documents: [Self]) -> [Self] {
        var seen = Set<UUID>()
        var characters = 0
        var result: [Self] = []
        for document in documents.sorted(by: { $0.updatedAt > $1.updatedAt })
            where document.isValid && seen.insert(document.id).inserted {
            guard result.count < maximumDocuments,
                  characters + document.characterCount <= maximumLibraryCharacters else { continue }
            result.append(document)
            characters += document.characterCount
        }
        return result
    }
}
