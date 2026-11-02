import LocalAuthentication
import SwiftUI

struct BoardOnlyUnlockView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var errorMessage: String?
    @State private var deviceAuthenticationAvailable = false
    @FocusState private var isPINFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter the PIN to return to all tabs and editing controls.")
                        .foregroundStyle(.secondary)
                }
                Section("PIN") {
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.password)
                        .focused($isPINFocused)
                        .accessibilityIdentifier("board-only-unlock-pin")
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                    Button("Leave board-only mode", systemImage: "lock.open") { unlockWithPIN() }
                        .disabled(pin.isEmpty)
                        .accessibilityIdentifier("board-only-leave")
                }
                if deviceAuthenticationAvailable {
                    Section {
                        Button("Use device authentication", systemImage: "person.crop.circle") {
                            unlockWithDevice()
                        }
                        .accessibilityIdentifier("board-only-device-unlock")
                    }
                }
            }
            .navigationTitle("Leave board-only mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done typing") { isPINFocused = false }
                        .accessibilityIdentifier("board-only-unlock-keyboard-done")
                }
            }
            .onAppear {
                deviceAuthenticationAvailable = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            }
        }
    }

    private func unlockWithPIN() {
        isPINFocused = false
        if store.leaveBoardOnlyMode(pin: pin) {
            pin = ""
            dismiss()
        } else {
            pin = ""
            errorMessage = "That PIN did not match. Try again."
        }
    }

    private func unlockWithDevice() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Leave board-only mode and open editing controls") { success, error in
            Task { @MainActor in
                if success {
                    store.leaveBoardOnlyModeAfterDeviceAuthentication()
                    dismiss()
                } else if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
