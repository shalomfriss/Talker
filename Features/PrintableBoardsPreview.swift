import PDFKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PrintableBoardsPreview: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    var title = "Printable boards"
    var filename = "Open Voice Boards"
    @State private var showingExporter = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            PrintablePDFView(data: data)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ShareLink(item: PrintablePDFTransfer(data: data), preview: SharePreview(filename)) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("share-pdf")
                        Button("Save PDF", systemImage: "square.and.arrow.down") {
                            showingExporter = true
                        }
                        Button("Print", systemImage: "printer") {
                            let controller = UIPrintInteractionController.shared
                            let info = UIPrintInfo(dictionary: nil)
                            info.outputType = .general
                            info.jobName = filename
                            controller.printInfo = info
                            controller.printingItem = data
                            controller.present(animated: true, completionHandler: nil)
                        }
                    }
                }
                .fileExporter(isPresented: $showingExporter,
                              document: PrintablePDFDocument(data: data),
                              contentType: .pdf, defaultFilename: filename) { result in
                    if case .failure(let error) = result { exportError = error.localizedDescription }
                }
                .alert("PDF error", isPresented: Binding(
                    get: { exportError != nil }, set: { if !$0 { exportError = nil } }
                )) {
                    Button("OK") { exportError = nil }
                } message: {
                    Text(exportError ?? "Unknown error")
                }
        }
    }
}

private struct PrintablePDFView: UIViewRepresentable {
    let data: Data

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(data: data)
        context.coordinator.lastData = data
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard context.coordinator.lastData != data else { return }
        view.document = PDFDocument(data: data)
        context.coordinator.lastData = data
    }

    final class Coordinator {
        var lastData: Data?
    }
}
