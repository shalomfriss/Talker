import Foundation

struct PDFPreviewPayload: Identifiable {
    let id = UUID()
    let data: Data
}
