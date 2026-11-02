import SwiftUI

struct BoardAppearanceView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var icon = ""
    @State private var isVisible = true
    @State private var showsTileLabels = true
    @State private var errorMessage: String?

    let boardName: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Board icon") {
                    TextField("Emoji or short symbol", text: $icon)
                        .accessibilityIdentifier("board-icon-input")
                    Text("Shown beside the board name. Use up to four characters; leave blank for no icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Show \(boardName) in board bar", isOn: $isVisible)
                        .accessibilityIdentifier("board-visible-toggle")
                } header: {
                    Text("Board bar")
                } footer: {
                    Text("Hidden boards stay available through linked buttons and Find a word. A hidden pinned board also leaves the pinned strip.")
                }
                Section("Picture buttons") {
                    Toggle("Show button labels", isOn: $showsTileLabels)
                        .accessibilityIdentifier("board-tile-labels-toggle")
                    Text("Hide text under pictures and symbols on this board. Buttons with only a generic speech bubble keep their text; VoiceOver still names every button.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(boardName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(icon.trimmingCharacters(in: .whitespacesAndNewlines).count > 4)
                        .accessibilityIdentifier("board-appearance-save")
                }
            }
            .alert("Board appearance", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                icon = store.boardIcon(for: boardName) ?? ""
                isVisible = store.visibleBoards.contains(boardName)
                showsTileLabels = store.boardTileLabelsVisible(for: boardName)
            }
        }
    }

    private func save() {
        guard store.setBoardVisible(isVisible, for: boardName) else {
            errorMessage = "Keep at least one board in the board bar."
            return
        }
        guard store.setBoardIcon(icon, for: boardName) else {
            errorMessage = "Use no more than four characters for the icon."
            return
        }
        _ = store.setBoardTileLabelsVisible(showsTileLabels, for: boardName)
        dismiss()
    }
}
