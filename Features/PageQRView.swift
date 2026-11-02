import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

struct PageQRShareView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var image: UIImage?
    @State private var imageURL: URL?
    @State private var errorMessage: String?

    let boardName: String

    var body: some View {
        NavigationStack {
            List {
                if let image {
                    Section {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 360)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("QR code for \(boardName)")
                            .accessibilityIdentifier("page-qr-image")
                    } header: {
                        Text(boardName)
                    } footer: {
                        Text("On another Open Voice device, choose Import page QR, then scan this code or import its image.")
                    }
                    Section {
                        Button("Copy page code", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = code
                        }
                        .accessibilityIdentifier("copy-page-qr-code")
                        if let imageURL {
                            ShareLink(item: imageURL) {
                                Label("Share QR image", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("share-page-qr-image")
                        }
                    }
                } else if let errorMessage {
                    ContentUnavailableView("Page QR unavailable", systemImage: "qrcode",
                                           description: Text(errorMessage))
                } else {
                    ProgressView("Preparing QR code")
                }
                Section {
                    Text("Page QR carries vocabulary text, symbols, translations, and button styles. Use Export board (.obf) for photos, recordings, links, or a page too large for one code.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Share page QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .task { prepare() }
        }
    }

    private func prepare() {
        do {
            let code = try store.qrCodeForBoard(boardName)
            let image = try QRPageImage.make(code)
            guard let png = image.pngData() else { throw QRPageTransferError.tooLarge }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("open-voice-page-\(UUID().uuidString).png")
            try png.write(to: url, options: .atomic)
            self.code = code
            self.image = image
            imageURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PageQRImportView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingPage: QRPageContent?
    @State private var showingScanner = false
    @State private var errorMessage: String?
    @State private var addedBoardName: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Scan a page QR from another device, import a QR image, or paste a copied page code. Review the vocabulary before adding it to \(store.activeProfileName).")
                        .foregroundStyle(.secondary)
                }
                Section("Load a page") {
                    if DataScannerViewController.isSupported {
                        Button("Scan with camera", systemImage: "qrcode.viewfinder") {
                            Task { await openScanner() }
                        }
                        .accessibilityIdentifier("scan-page-qr")
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Import QR image", systemImage: "photo.on.rectangle")
                    }
                    .accessibilityIdentifier("import-page-qr-image")
                    Button("Paste page code", systemImage: "doc.on.clipboard") {
                        load(UIPasteboard.general.string ?? "")
                    }
                    .accessibilityIdentifier("paste-page-qr-code")
                }
                if let pendingPage {
                    Section("Page preview") {
                        LabeledContent("Board", value: pendingPage.title)
                        LabeledContent("Buttons", value: "\(pendingPage.tiles.count)")
                        ForEach(Array(pendingPage.tiles.prefix(8).enumerated()), id: \.offset) { _, tile in
                            HStack(spacing: 10) {
                                Text(tile.symbol).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tile.label)
                                    if let spanish = tile.spanish {
                                        Text(spanish.label)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if pendingPage.tiles.count > 8 {
                            Text("And \(pendingPage.tiles.count - 8) more buttons")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Import page QR")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let pendingPage {
                    Button("Add page to current profile", systemImage: "plus.square.on.square") {
                        addedBoardName = store.addQRPage(pendingPage)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("add-imported-qr-page")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task { await importImage(photo) }
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    LivePageQRScanner { code in
                        showingScanner = false
                        load(code)
                    } onError: { message in
                        showingScanner = false
                        errorMessage = message
                    }
                    .navigationTitle("Scan page QR")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingScanner = false }
                        }
                    }
                }
            }
            .alert("Page added", isPresented: Binding(
                get: { addedBoardName != nil }, set: { if !$0 { addedBoardName = nil } }
            )) {
                Button("OK") { dismiss() }
            } message: {
                if let addedBoardName {
                    Text("Added \(addedBoardName) to \(store.activeProfileName).")
                }
            }
            .alert("Could not load page QR", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try another code or image.")
            }
        }
    }

    private func load(_ code: String) {
        do {
            pendingPage = try QRPageTransfer.decode(code)
        } catch {
            pendingPage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func importImage(_ photo: PhotosPickerItem) async {
        do {
            guard let data = try await photo.loadTransferable(type: Data.self),
                  data.count <= 16_000_000 else { throw QRPageTransferError.invalidCode }
            let code = try QRPageImage.read(from: data)
            load(code)
        } catch {
            pendingPage = nil
            errorMessage = error.localizedDescription
        }
    }

    private func openScanner() async {
        guard DataScannerViewController.isSupported else {
            errorMessage = "Camera scanning is unavailable on this device. Import an image or paste a code."
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted, DataScannerViewController.isAvailable else {
            errorMessage = "Allow camera access in Settings, or import a QR image."
            return
        }
        showingScanner = true
    }
}

private struct LivePageQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> PageQRScannerHostController {
        let controller = PageQRScannerHostController()
        controller.scanner.delegate = context.coordinator
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ controller: PageQRScannerHostController, context: Context) { }

    static func dismantleUIViewController(_ controller: PageQRScannerHostController, coordinator: Coordinator) {
        controller.scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                onCode(code)
            }
        }
    }
}

@MainActor
private final class PageQRScannerHostController: UIViewController {
    let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                            qualityLevel: .balanced, recognizesMultipleItems: false,
                                            isHighFrameRateTrackingEnabled: false,
                                            isGuidanceEnabled: true, isHighlightingEnabled: true)
    var onError: (String) -> Void = { _ in }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanner.view)
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do { try scanner.startScanning() }
        catch { onError(error.localizedDescription) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        scanner.stopScanning()
        super.viewWillDisappear(animated)
    }
}
