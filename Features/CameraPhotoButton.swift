import SwiftUI
import UIKit

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
