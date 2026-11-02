import SwiftUI
import UniformTypeIdentifiers

struct StoriesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showingAdd = false
    @State private var newTitle = ""
    @State private var renamingStory: VisualStory?
    @State private var renamedTitle = ""
    @State private var showingStoryImporter = false
    @State private var showingStoryExporter = false
    @State private var storyExportDocument: BackupDocument?
    @State private var storyExportName = "story.json"
    @State private var transferMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Make a story about your day, or show what may happen next.")
                        .foregroundStyle(.secondary)
                }
                Section("My stories") {
                    ForEach(store.stories) { story in
                        HStack {
                            NavigationLink {
                                StoryReaderView(storyID: story.id)
                            } label: {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text(story.title)
                                        Text("\(story.pages.count) pages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "book.closed.fill")
                                }
                            }
                            Menu {
                                Button("Export story file", systemImage: "square.and.arrow.up") {
                                    exportStory(story)
                                }
                                Button("Rename", systemImage: "pencil") {
                                    renamingStory = story
                                    renamedTitle = story.title
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    store.deleteStory(id: story.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("Actions for \(story.title)")
                        }
                        .swipeActions {
                            Button("Export") { exportStory(story) }
                            Button("Rename") {
                                renamingStory = story
                                renamedTitle = story.title
                            }
                            Button("Delete", role: .destructive) { store.deleteStory(id: story.id) }
                        }
                    }
                    Button("Create a story", systemImage: "plus") { showingAdd = true }
                    Button("Import story file", systemImage: "square.and.arrow.down") {
                        showingStoryImporter = true
                    }
                    .accessibilityIdentifier("import-story-file")
                }
            }
            .navigationTitle("Stories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import story file", systemImage: "square.and.arrow.down") {
                        showingStoryImporter = true
                    }
                    .accessibilityIdentifier("story-import-toolbar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add story", systemImage: "plus") { showingAdd = true }
                }
            }
            .alert("New story", isPresented: $showingAdd) {
                TextField("Story title", text: $newTitle)
                Button("Create") {
                    _ = store.addStory(newTitle)
                    newTitle = ""
                }
                Button("Cancel", role: .cancel) { newTitle = "" }
            } message: {
                Text("Give this story a name. You can add pages after creating it.")
            }
            .alert("Rename story", isPresented: Binding(
                get: { renamingStory != nil }, set: { if !$0 { renamingStory = nil } }
            )) {
                TextField("Story title", text: $renamedTitle)
                Button("Save") {
                    if let renamingStory { store.renameStory(id: renamingStory.id, title: renamedTitle) }
                    renamingStory = nil
                }
                Button("Cancel", role: .cancel) { renamingStory = nil }
            }
            .fileExporter(isPresented: $showingStoryExporter, document: storyExportDocument,
                          contentType: .json, defaultFilename: storyExportName) { result in
                showingStoryExporter = false
                storyExportDocument = nil
                if case .failure(let error) = result { transferMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingStoryImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom: url)
                    defer { try? file.close() }
                    let data = try file.read(upToCount: StoryTransfer.maxImportBytes + 1) ?? Data()
                    guard data.count <= StoryTransfer.maxImportBytes else { throw StoryTransferError.tooLarge }
                    let imported = try store.importStory(data)
                    transferMessage = "Added \(imported.title) to My stories."
                } catch {
                    transferMessage = error.localizedDescription
                }
            }
            .alert("Story file", isPresented: Binding(
                get: { transferMessage != nil }, set: { if !$0 { transferMessage = nil } }
            )) {
                Button("OK") { transferMessage = nil }
            } message: {
                Text(transferMessage ?? "")
            }
            .onChange(of: store.activeProfileID) { _, _ in
                showingAdd = false
                newTitle = ""
                renamingStory = nil
                renamedTitle = ""
                showingStoryImporter = false
                showingStoryExporter = false
                storyExportDocument = nil
            }
        }
    }

    private func exportStory(_ story: VisualStory) {
        do {
            storyExportDocument = BackupDocument(data: try StoryTransfer.exportData(story))
            storyExportName = story.title.replacingOccurrences(of: "/", with: "-") + ".json"
            showingStoryExporter = true
        } catch {
            transferMessage = error.localizedDescription
        }
    }
}
