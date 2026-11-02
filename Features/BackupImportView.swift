import SwiftUI

struct PendingBackupImport: Identifiable {
    let id = UUID()
    let data: Data
    let preview: StoredData
}

struct BackupImportView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let backup: PendingBackupImport

    @State private var selectedBoards = Set<String>()
    @State private var showingReplaceConfirmation = false
    @State private var importedNames: [String]?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("This backup has \(backup.preview.categories.count) boards and \(backup.preview.items.count) buttons.")
                    Text("Choose boards to add as copies while keeping this profile’s other data.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(backup.preview.categories, id: \.self) { name in
                        Toggle(isOn: Binding(
                            get: { selectedBoards.contains(name) },
                            set: { isSelected in
                                if isSelected { selectedBoards = selectedBoards.union([name]) }
                                else { selectedBoards = selectedBoards.subtracting([name]) }
                            }
                        )) {
                            HStack {
                                Text(name)
                                Spacer()
                                Text("\(backup.preview.items.filter { $0.category == name }.count) buttons")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("backup-select-\(name)")
                    }
                } header: {
                    Text("Boards to add")
                } footer: {
                    Text("Existing boards stay in place. A copied board gets a new name when its name is already used. Links between selected boards and their personal media are included.")
                }
                Section {
                    Button("Replace current profile", systemImage: "arrow.counterclockwise", role: .destructive) {
                        showingReplaceConfirmation = true
                    }
                    .accessibilityIdentifier("backup-replace-profile")
                } footer: {
                    Text("Full restore replaces this profile’s words, phrases, jokes, scenes, choice boards, routines, weekly plan, stories, passport, logs, and settings.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add \(selectedBoards.count) selected \(selectedBoards.count == 1 ? "board" : "boards")",
                       systemImage: "square.on.square") {
                    do {
                        importedNames = try store.addBoards(fromBackup: backup.data,
                                                             selectedBoards: selectedBoards)
                    } catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(selectedBoards.isEmpty)
                .accessibilityIdentifier("backup-add-selected")
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
            .navigationTitle("Import backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .confirmationDialog("Replace everything in the current profile with this backup?",
                                isPresented: $showingReplaceConfirmation) {
                Button("Replace current data", role: .destructive) {
                    do {
                        try store.importBackup(backup.data)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Export a backup first if you want to keep the current data.")
            }
            .alert("Added \(importedNames?.count ?? 0) boards", isPresented: Binding(
                get: { importedNames != nil }, set: { if !$0 { importedNames = nil } }
            )) {
                Button("Done") { dismiss() }
            } message: {
                Text("The selected boards are now available in this profile.")
            }
            .alert("Import error", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
}
