import SwiftUI

struct BackupPreviewSummary: Sendable {
    let categories: [String]
    let buttonCount: Int
    let buttonCountsByCategory: [String: Int]

    init(_ backup: StoredData) {
        categories = backup.categories
        buttonCount = backup.items.count
        var counts: [String: Int] = [:]
        for item in backup.items { counts[item.category, default: 0] += 1 }
        buttonCountsByCategory = counts
    }
}

struct PendingBackupImport: Identifiable, Sendable {
    let id = UUID()
    let data: Data
    let preview: BackupPreviewSummary

    static func load(from url: URL) async throws -> PendingBackupImport {
        try await Task.detached(priority: .userInitiated) { @Sendable in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try prepared(data: data)
        }.value
    }

    static func prepare(data: Data) async throws -> PendingBackupImport {
        try await Task.detached(priority: .userInitiated) { @Sendable in
            try prepared(data: data)
        }.value
    }

    private static func prepared(data: Data) throws -> PendingBackupImport {
        let decoded = try JSONDecoder().decode(StoredData.self, from: data)
        guard !decoded.items.isEmpty else { throw BackupError.emptyVocabulary }
        return PendingBackupImport(data: data, preview: BackupPreviewSummary(decoded))
    }
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
                    Text("This backup has \(backup.preview.categories.count) boards and \(backup.preview.buttonCount) buttons.")
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
                                Text("\(backup.preview.buttonCountsByCategory[name, default: 0]) buttons")
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
