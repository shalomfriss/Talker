import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct PrintablePDFTransfer: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
    }
}
