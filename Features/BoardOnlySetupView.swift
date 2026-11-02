import SwiftUI

struct BoardOnlySetupView: View {
    private enum PINField: Hashable { case pin, confirmation }

    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: PINField?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose a PIN to leave board-only mode. Keep it somewhere you can find it. Device authentication can also unlock when it is available.")
                        .foregroundStyle(.secondary)
                }
                Section("PIN") {
                    SecureField("4 to 8 numbers", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .pin)
                        .accessibilityIdentifier("board-only-new-pin")
                    SecureField("Confirm PIN", text: $confirmation)
                        .keyboardType(.numberPad)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmation)
                        .accessibilityIdentifier("board-only-confirm-pin")
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Start board-only mode", systemImage: "lock.fill") { start() }
                        .buttonStyle(.borderedProminent)
                        .disabled(pin.isEmpty || confirmation.isEmpty)
                        .accessibilityIdentifier("board-only-start")
                }
            }
            .navigationTitle("Board-only mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done typing") { focusedField = nil }
                        .accessibilityIdentifier("board-only-keyboard-done")
                }
            }
        }
    }

    private func start() {
        focusedField = nil
        guard pin == confirmation else {
            errorMessage = "The PINs do not match."
            return
        }
        do {
            try store.startBoardOnlyMode(pin: pin)
            pin = ""
            confirmation = ""
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
