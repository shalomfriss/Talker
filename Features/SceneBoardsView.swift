import SwiftUI
import UniformTypeIdentifiers

struct SceneBoardsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: ScenePresentation?
    @State private var showingSceneImporter = false
    @State private var showingSceneExporter = false
    @State private var sceneExportDocument: BackupDocument?
    @State private var sceneExportName = "scene.json"
    @State private var transferMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Use a familiar photo or short video to talk about a place, activity, or person. Tap a word on the scene, or return to the full Speak board at any time.")
                        .foregroundStyle(.secondary)
                }
                Section("My scenes") {
                    ForEach(store.sceneBoards) { board in
                        HStack(spacing: 12) {
                            Button { presentation = .session(board) } label: {
                                HStack(spacing: 12) {
                                    AsyncThumbnailImage(data: board.imageData, maxPixelSize: 180) {
                                        Color(uiColor: .secondarySystemBackground)
                                    }
                                            .frame(width: 72, height: 54)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(board.title).font(.headline)
                                        Text("\(board.hotspots.count) words · \(board.isVideoScene ? "Video" : "Photo")")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(board.title) scene")
                            if !store.isBoardOnlyModeActive {
                                Menu {
                                    Button("Export scene file", systemImage: "square.and.arrow.up") {
                                        exportScene(board)
                                    }
                                    Button("Edit", systemImage: "pencil") { presentation = .editing(board) }
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        store.deleteSceneBoard(id: board.id)
                                    }
                                } label: { Image(systemName: "ellipsis.circle") }
                                    .accessibilityLabel("Options for \(board.title)")
                            }
                        }
                    }
                    if !store.isBoardOnlyModeActive {
                        Button("Create a scene", systemImage: "plus") { presentation = .newScene }
                            .accessibilityIdentifier("create-scene")
                        Button("Import scene file", systemImage: "square.and.arrow.down") {
                            showingSceneImporter = true
                        }
                        .accessibilityIdentifier("import-scene-file")
                    }
                }
            }
            .navigationTitle("Scenes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                if !store.isBoardOnlyModeActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New scene", systemImage: "plus") { presentation = .newScene }
                    }
                }
            }
            .sheet(item: $presentation) { presented in
                switch presented {
                case .session(let board):
                    SceneSessionView(board: board) {
                        presentation = nil
                        dismiss()
                    }
                case .editing(let board):
                    SceneEditorView(board: board)
                case .newScene:
                    SceneEditorView(board: nil)
                }
            }
            .fileExporter(isPresented: $showingSceneExporter, document: sceneExportDocument,
                          contentType: .json, defaultFilename: sceneExportName) { result in
                if case .failure(let error) = result { transferMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingSceneImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { try? file.close() }
                    let data = try file.read(upToCount: SceneBoardTransfer.maxImportBytes + 1) ?? Data()
                    guard data.count <= SceneBoardTransfer.maxImportBytes else {
                        throw SceneBoardTransferError.tooLarge
                    }
                    let imported = try store.importSceneBoard(data)
                    transferMessage = "Added \(imported.title) to My scenes."
                } catch { transferMessage = error.localizedDescription }
            }
            .alert("Scene file", isPresented: Binding(
                get: { transferMessage != nil }, set: { if !$0 { transferMessage = nil } }
            )) {
                Button("OK") { transferMessage = nil }
            } message: {
                Text(transferMessage ?? "")
            }
            .onChange(of: store.isBoardOnlyModeActive) { _, active in
                if active, presentation?.isEditing == true { presentation = nil }
            }
        }
    }

    private func exportScene(_ board: VisualSceneBoard) {
        do {
            sceneExportDocument = BackupDocument(data: try SceneBoardTransfer.exportData(
                board, using: store.items, allBoards: store.sceneBoards))
            sceneExportName = board.title.replacingOccurrences(of: "/", with: "-") + ".json"
            showingSceneExporter = true
        } catch { transferMessage = error.localizedDescription }
    }
}

private enum ScenePresentation: Identifiable {
    case session(VisualSceneBoard)
    case editing(VisualSceneBoard)
    case newScene

    var id: String {
        switch self {
        case .session(let board): "session-\(board.id)"
        case .editing(let board): "editing-\(board.id)"
        case .newScene: "new"
        }
    }

    var isEditing: Bool {
        switch self {
        case .session: false
        case .editing, .newScene: true
        }
    }
}
