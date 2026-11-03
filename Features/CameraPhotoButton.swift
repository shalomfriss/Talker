import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CameraPhotoButton: View {
    var title: String = "Take photo"
    var identifier: String = "take-photo"
    let onCapture: (Data) -> Void
    @State private var showingCamera = false
    @State private var showingCaptureError = false

    var body: some View {
        Button(title, systemImage: "camera") {
            if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
        }
        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        .accessibilityIdentifier(identifier)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPhotoPicker { data in
                if let data { onCapture(data) }
                else { showingCaptureError = true }
            }
            .ignoresSafeArea()
        }
        .alert("Could not use photo", isPresented: $showingCaptureError) {
            Button("OK") {}
        } message: {
            Text("Try taking another photo or choose one from Photos.")
        }
    }
}

struct PastePhotoButton: View {
    var title: String = "Paste image"
    var identifier: String = "paste-photo"
    var onPastingChange: ((Bool) -> Void)? = nil
    let onPaste: (Data) -> Void
    @State private var isPasting = false
    @State private var showingPasteError = false

    var body: some View {
        Button(isPasting ? "Pasting image…" : title, systemImage: "doc.on.clipboard") {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-paste-photo") {
                UIPasteboard.general.image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48))
                    .image { context in
                        UIColor.systemTeal.setFill()
                        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
                    }
            }
#endif
            guard let source = UIPasteboard.general.itemProviders.lazy.compactMap({ provider in
                provider.registeredContentTypes.first(where: { $0.conforms(to: .image) })
                    .map { (provider, $0) }
            }).first else {
                showingPasteError = true
                return
            }
            isPasting = true
            onPastingChange?(true)
            source.0.loadDataRepresentation(for: source.1) { data, _ in
                Task { @MainActor in
                    defer {
                        isPasting = false
                        onPastingChange?(false)
                    }
                    var prepared: Data?
                    if let data {
                        prepared = await PhotoProcessing.preparedDataAsync(from: data)
                    }
                    if prepared == nil, let fallback = UIPasteboard.general.image?.pngData() {
                        prepared = await PhotoProcessing.preparedDataAsync(from: fallback)
                    }
                    guard let prepared else {
                        showingPasteError = true
                        return
                    }
                    onPaste(prepared)
                }
            }
        }
        .disabled(isPasting)
        .accessibilityIdentifier(identifier)
        .alert("Could not paste image", isPresented: $showingPasteError) {
            Button("OK") {}
        } message: {
            Text("Copy an image in another app, then tap Paste image here.")
        }
    }
}
