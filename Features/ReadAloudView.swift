import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ReadAloudView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var document = ReadAloudDocument(title: "Your text", pages: [""])
    @State private var pageIndex = 0
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showingLibrary = false
    @State private var showingSavePrompt = false
    @State private var saveTitle = ""
    @State private var savedDocumentID: UUID?
    @State private var documentToDelete: SavedReadingDocument?
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var pageText: String { document.pages[pageIndex] }
    private var hasReadableText: Bool {
        document.pages.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var pageBinding: Binding<String> {
        Binding(get: { document.pages[pageIndex] }, set: { newValue in
            stopDocumentSpeech()
            document.pages[pageIndex] = newValue
        })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Open a PDF, text file, or page image. You can also paste or type below. Text stays on this device and is not added to message history.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Files", systemImage: "folder") { showingFileImporter = true }
                                .accessibilityIdentifier("read-aloud-files")
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Photos", systemImage: "photo")
                            }
                            .accessibilityIdentifier("read-aloud-photos")
                            CameraPhotoButton { data in
                                Task { await load(data, fileName: "Scanned page.jpg") }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                        HStack(spacing: 12) {
                            Button("Saved readings", systemImage: "books.vertical") {
                                showingLibrary = true
                            }
                            .accessibilityIdentifier("read-aloud-library")
                            Button(savedDocumentID == nil ? "Save text" : "Save changes",
                                   systemImage: "square.and.arrow.down") {
                                saveTitle = document.title
                                showingSavePrompt = true
                            }
                            .disabled(isLoading || !hasReadableText)
                            .accessibilityIdentifier("read-aloud-save")
                        }
                        .buttonStyle(.bordered)
                        if isLoading { ProgressView("Reading page") }
                        Text(document.title)
                            .font(.headline)
                            .accessibilityIdentifier("read-aloud-title")
                        if document.pages.count > 1 {
                            HStack {
                                Button("Previous page", systemImage: "chevron.left") {
                                    changePage(by: -1)
                                }
                                .disabled(pageIndex == 0)
                                Spacer()
                                Text("Page \(pageIndex + 1) of \(document.pages.count)")
                                    .accessibilityIdentifier("read-aloud-page-count")
                                Spacer()
                                Button("Next page", systemImage: "chevron.right") {
                                    changePage(by: 1)
                                }
                                .disabled(pageIndex == document.pages.count - 1)
                            }
                            .buttonStyle(.bordered)
                        }
                        if let highlight = store.speechHighlight, highlight.source == .document {
                            SpeechFollowAlongView(state: highlight)
                                .accessibilityIdentifier("read-aloud-follow-along")
                        }
                        TextEditor(text: pageBinding)
                            .frame(minHeight: 240)
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.gray.opacity(0.3)))
                            .accessibilityLabel("Page text")
                            .accessibilityIdentifier("read-aloud-text")
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                VStack(spacing: 0) {
                    Button("Read page", systemImage: "speaker.wave.2.fill") {
                        store.speak(pageText, followAlong: .document)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .accessibilityIdentifier("read-aloud-speak")
                    .padding(8)
                    MessagePlaybackControl(source: .document)
                }
            }
            .navigationTitle("Read aloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.pdf, .plainText, .image]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url, options: .mappedIfSafe)
                        Task { await load(data, fileName: url.lastPathComponent) }
                    } catch { errorMessage = error.localizedDescription }
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self) else {
                            throw ReadAloudDocumentError.unreadableFile
                        }
                        await load(data, fileName: "Page photo.jpg")
                    } catch { errorMessage = error.localizedDescription }
                    selectedPhoto = nil
                }
            }
            .sheet(isPresented: $showingLibrary) { librarySheet }
            .alert("Save reading", isPresented: $showingSavePrompt) {
                TextField("Title", text: $saveTitle)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveCurrentDocument() }
            } message: {
                Text("Saves the editable text in this profile and its backups. The original file or photo is not kept.")
            }
            .alert("Read aloud", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onDisappear { stopDocumentSpeech() }
        }
    }

    private func load(_ data: Data, fileName: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let parsed = try await Task.detached(priority: .userInitiated) {
                try ReadAloudDocument.imported(data: data, fileName: fileName)
            }.value
            stopDocumentSpeech()
            document = parsed
            pageIndex = 0
            savedDocumentID = nil
        } catch { errorMessage = error.localizedDescription }
    }

    private var librarySheet: some View {
        NavigationStack {
            List {
                if store.savedReadingDocuments.isEmpty {
                    ContentUnavailableView("No saved readings", systemImage: "books.vertical",
                                           description: Text("Save a page after you import or type it."))
                }
                ForEach(store.savedReadingDocuments) { saved in
                    HStack(spacing: 12) {
                        Button {
                            stopDocumentSpeech()
                            document = saved.readingDocument
                            pageIndex = 0
                            savedDocumentID = saved.id
                            showingLibrary = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(saved.title).font(.headline)
                                Text("\(saved.pages.count) \(saved.pages.count == 1 ? "page" : "pages")")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("saved-reading-\(saved.id)")
                        Button("Delete reading", systemImage: "trash", role: .destructive) {
                            documentToDelete = saved
                            showingDeleteConfirmation = true
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Delete \(saved.title)")
                        .accessibilityIdentifier("delete-saved-reading-\(saved.id)")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationTitle("Saved readings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { showingLibrary = false }
            } }
            .alert("Delete saved reading?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let documentToDelete {
                        store.deleteReadingDocument(id: documentToDelete.id)
                        if savedDocumentID == documentToDelete.id { savedDocumentID = nil }
                    }
                    documentToDelete = nil
                }
                Button("Cancel", role: .cancel) { documentToDelete = nil }
            } message: {
                Text(documentToDelete?.title ?? "")
            }
        }
    }

    private func saveCurrentDocument() {
        do {
            let id = try store.saveReadingDocument(title: saveTitle, pages: document.pages,
                                                   existingID: savedDocumentID)
            savedDocumentID = id
            document.title = saveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { errorMessage = error.localizedDescription }
    }

    private func changePage(by offset: Int) {
        let target = pageIndex + offset
        guard document.pages.indices.contains(target) else { return }
        stopDocumentSpeech()
        pageIndex = target
    }

    private func stopDocumentSpeech() {
        if store.messagePlaybackState?.source == .document
            || store.speechHighlight?.source == .document {
            store.stopSpeaking()
        }
    }
}
