import SwiftUI
import UniformTypeIdentifiers

struct LocalBackupsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var backups: [LocalBackupSnapshot] = []
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var pendingBackup: PendingBackupImport?
    @State private var openingBackupID: UUID?
    @State private var pendingDelete: LocalBackupSnapshot?
    @State private var exportDocument: BackupDocument?
    @State private var exportName = "open-voice-backup"
    @State private var showingExporter = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button("Create local backup", systemImage: "plus") { showingCreate = true }
                    .accessibilityIdentifier("create-local-backup")
            } footer: {
                Text("Local backups stay on this device. Export a backup file to keep a copy elsewhere.")
            }
            Section("Saved backups") {
                if openingBackupID != nil { ProgressView("Reading backup") }
                if backups.isEmpty {
                    Text("No local backups for this profile yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(backups) { snapshot in
                    HStack {
                        Button {
                            open(snapshot)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.name).font(.headline)
                                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(openingBackupID != nil)
                        .accessibilityIdentifier("open-local-backup-\(snapshot.id.uuidString)")
                        Menu {
                            Button("Export JSON file", systemImage: "square.and.arrow.up") { export(snapshot) }
                            Button("Delete backup", systemImage: "trash", role: .destructive) {
                                pendingDelete = snapshot
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Options for \(snapshot.name)")
                    }
                }
            }
        }
        .navigationTitle("Local backups")
        .onAppear(perform: refresh)
        .alert("New local backup", isPresented: $showingCreate) {
            TextField("Backup name", text: $newName)
            Button("Create") {
                do {
                    try store.createLocalBackup(named: newName)
                    newName = ""
                    refresh()
                } catch { errorMessage = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Save a copy of the current profile’s boards, messages, routines, stories, and settings.")
        }
        .confirmationDialog("Delete \(pendingDelete?.name ?? "this backup")?",
                            isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete backup", role: .destructive) {
                if let pendingDelete {
                    do { try store.deleteLocalBackup(id: pendingDelete.id); refresh() }
                    catch { errorMessage = error.localizedDescription }
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
        .sheet(item: $pendingBackup) { backup in
            BackupImportView(backup: backup)
                .environmentObject(store)
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument,
                      contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("Backup error", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func refresh() {
        do { backups = try store.localBackups() }
        catch { errorMessage = error.localizedDescription }
    }

    private func open(_ snapshot: LocalBackupSnapshot) {
        guard openingBackupID == nil else { return }
        openingBackupID = snapshot.id
        let profileID = store.activeProfileID
        Task {
            defer { openingBackupID = nil }
            do {
                let data = try await store.localBackupDataAsync(id: snapshot.id)
                let prepared = try await PendingBackupImport.prepare(data: data)
                guard store.activeProfileID == profileID else { return }
                pendingBackup = prepared
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func export(_ snapshot: LocalBackupSnapshot) {
        do {
            exportDocument = BackupDocument(data: try store.localBackupData(id: snapshot.id))
            exportName = "open-voice-\(snapshot.id.uuidString.prefix(8))"
            showingExporter = true
        } catch { errorMessage = error.localizedDescription }
    }
}
