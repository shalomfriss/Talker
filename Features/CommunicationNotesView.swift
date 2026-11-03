import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct CommunicationNotesView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onUseInDraft: () -> Void
    @State private var searchText = ""
    @State private var selectedTopic: String?
    @State private var showingNewNote = false
    @State private var editingNote: CommunicationNote?
    @State private var deletingNote: CommunicationNote?

    private var topics: [String] {
        Array(Set(store.notes.map(\.topic)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var visibleNotes: [CommunicationNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.notes.filter { note in
            (selectedTopic == nil || note.topic == selectedTopic) &&
            (query.isEmpty || note.title.localizedStandardContains(query) ||
             note.topic.localizedStandardContains(query) || note.text.localizedStandardContains(query))
        }
    }

    private var visibleTopics: [String] {
        topics.filter { topic in visibleNotes.contains(where: { $0.topic == topic }) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Keep information for a conversation. Notes stay with this profile and are included in its backups. They are not spoken or added to recent messages unless you choose to speak them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        LifeNotebookView()
                    } label: {
                        Label("Life notebook", systemImage: "photo.on.rectangle.angled")
                    }
                    .accessibilityIdentifier("open-life-notebook")
                }
                if visibleNotes.isEmpty {
                    ContentUnavailableView(searchText.isEmpty && store.notes.isEmpty ? "No notes yet" : "No matching notes",
                                           systemImage: "note.text",
                                           description: Text(store.notes.isEmpty ? "Add a note to prepare something you want to say." : "Try another search or topic."))
                } else {
                    ForEach(visibleTopics, id: \.self) { topic in
                        Section(topic) {
                            ForEach(visibleNotes.filter { $0.topic == topic }) { note in
                                noteRow(note)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .onChange(of: topics) { _, available in
                if let selectedTopic, !available.contains(selectedTopic) { self.selectedTopic = nil }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All topics") { selectedTopic = nil }
                        ForEach(topics, id: \.self) { topic in
                            Button(topic) { selectedTopic = topic }
                        }
                    } label: {
                        Label(selectedTopic ?? "All topics", systemImage: "line.3.horizontal.decrease")
                    }
                    .disabled(topics.isEmpty)
                    .accessibilityIdentifier("notes-topic-filter")
                }
                if !store.isBoardOnlyModeActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New note", systemImage: "plus") { showingNewNote = true }
                            .accessibilityIdentifier("new-note")
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) { CommunicationNoteEditorView(note: nil) }
            .sheet(item: $editingNote) { CommunicationNoteEditorView(note: $0) }
            .confirmationDialog("Delete note?", isPresented: Binding(
                get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } }
            )) {
                Button("Delete note", role: .destructive) {
                    if let deletingNote { _ = store.deleteNote(id: deletingNote.id) }
                    deletingNote = nil
                }
                Button("Cancel", role: .cancel) { deletingNote = nil }
            } message: {
                Text("This note will be removed from the current profile.")
            }
        }
    }

    private func noteRow(_ note: CommunicationNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title)
                .font(.headline)
            Text(note.text)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button("Speak", systemImage: "speaker.wave.2.fill") {
                    store.speakStandaloneMessage(note.text)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("speak-note-\(note.id)")
                Button("Use in text", systemImage: "text.badge.plus") {
                    guard store.appendTypedPhrase(note.text) else { return }
                    onUseInDraft()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Add this note to the current typed message")
                .accessibilityIdentifier("use-note-\(note.id)")
                Spacer(minLength: 0)
                Menu {
                    ShareLink(item: note.text) { Label("Share note", systemImage: "square.and.arrow.up") }
                    if !store.isBoardOnlyModeActive {
                        Button("Edit note", systemImage: "pencil") { editingNote = note }
                        Button("Delete note", systemImage: "trash", role: .destructive) { deletingNote = note }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Manage note \(note.title)")
                .accessibilityIdentifier("manage-note-\(note.id)")
            }
        }
        .padding(.vertical, 4)
    }
}

struct LifeNotebookView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var isLoading = true
    @State private var showingNewPost = false
    @State private var showingImporter = false
    @State private var editingPost: LifeNotebookPost?
    @State private var deletingPost: LifeNotebookPost?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Text("Save a photo, short video, caption, or picture words about an outing, activity, or highlight. Open a moment together to point, watch, talk, or speak. Posts stay on this device and in profile backups; individual moments can move by file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !store.isBoardOnlyModeActive {
                    Button("Import moment file", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                    .accessibilityIdentifier("import-life-notebook-post")
                }
            }
            if isLoading {
                ProgressView("Loading moments…")
            } else if store.lifeNotebookPosts.isEmpty {
                ContentUnavailableView("No moments yet", systemImage: "photo.on.rectangle.angled",
                                       description: Text("Add a moment to share something that happened."))
            } else {
                ForEach(store.lifeNotebookPosts) { post in
                    HStack(spacing: 12) {
                        NavigationLink {
                            LifeNotebookPostView(postID: post.id)
                        } label: {
                            HStack(spacing: 12) {
                                if let data = post.photoData {
                                    ZStack {
                                        AsyncThumbnailImage(data: data, maxPixelSize: 160) {
                                            Image(systemName: "photo")
                                                .font(.title)
                                        }
                                            .frame(width: 76, height: 76)
                                            .clipped()
                                        if post.videoData != nil {
                                            Image(systemName: "play.circle.fill")
                                                .font(.title)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                    }
                                    .frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .accessibilityHidden(true)
                                } else if let picture = post.pictograms?.first,
                                          let data = picture.imageData {
                                    AsyncThumbnailImage(data: data, maxPixelSize: 160) {
                                        Text(picture.symbol.isEmpty ? "💬" : picture.symbol)
                                            .font(.title)
                                    }
                                        .frame(width: 76, height: 76)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                        .accessibilityHidden(true)
                                } else if let picture = post.pictograms?.first {
                                    Text(picture.symbol.isEmpty ? "💬" : picture.symbol)
                                        .font(.title)
                                        .frame(width: 76, height: 76)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                                        .accessibilityHidden(true)
                                } else {
                                    Image(systemName: "text.bubble")
                                        .font(.title)
                                        .frame(width: 76, height: 76)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                                        .accessibilityHidden(true)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.title).font(.headline)
                                    Text(post.occurredAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !post.text.isEmpty {
                                        Text(post.text).lineLimit(2)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("life-notebook-post-\(post.id)")
                        if !store.isBoardOnlyModeActive {
                            Menu {
                                Button("Edit moment", systemImage: "pencil") { editingPost = post }
                                Button("Delete moment", systemImage: "trash", role: .destructive) {
                                    deletingPost = post
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Manage \(post.title)")
                        }
                    }
                }
            }
        }
        .navigationTitle("Life notebook")
        .toolbar {
            if !store.isBoardOnlyModeActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New moment", systemImage: "plus") { showingNewPost = true }
                        .accessibilityIdentifier("new-life-notebook-post")
                }
            }
        }
        .task(id: store.activeProfileID) {
            isLoading = true
            do { try await store.loadLifeNotebook() }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
        .sheet(isPresented: $showingNewPost) { LifeNotebookEditorView(post: nil) }
        .sheet(item: $editingPost) { LifeNotebookEditorView(post: $0) }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                Task {
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try await Task.detached(priority: .userInitiated) {
                            let file = try FileHandle(forReadingFrom: url)
                            defer { try? file.close() }
                            return try file.read(upToCount: LifeNotebookTransfer.maxImportBytes + 1) ?? Data()
                        }.value
                        let imported = try await store.importLifeNotebookPost(data)
                        errorMessage = "Added \(imported.title) to this notebook."
                    } catch { errorMessage = error.localizedDescription }
                }
            } catch { errorMessage = error.localizedDescription }
        }
        .confirmationDialog("Delete this moment?", isPresented: Binding(
            get: { deletingPost != nil }, set: { if !$0 { deletingPost = nil } }
        )) {
            Button("Delete moment", role: .destructive) {
                guard let post = deletingPost else { return }
                deletingPost = nil
                Task {
                    do { try await store.deleteLifeNotebookPost(id: post.id) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .alert("Life notebook", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

private struct LifeNotebookPostView: View {
    @EnvironmentObject private var store: CommunicationStore
    let postID: UUID
    @State private var showingVideo = false
    @State private var showingExporter = false
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var transferError: String?

    private var post: LifeNotebookPost? {
        store.lifeNotebookPosts.first { $0.id == postID }
    }

    private var exportFileName: String {
        let title = post?.title ?? "moment"
        let safe = title.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "Open-Voice-\(String(safe.prefix(40)))"
    }

    var body: some View {
        ScrollView {
            if let post {
                VStack(alignment: .leading, spacing: 20) {
                    if let data = post.photoData {
                        ZStack {
                            AsyncThumbnailImage(data: data, maxPixelSize: 1000, contentMode: .fit) {
                                Color(uiColor: .secondarySystemBackground)
                            }
                                .frame(maxWidth: .infinity)
                            if post.videoData != nil {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 3)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel(post.videoData == nil ? "Photo for \(post.title)" :
                                            "Video preview for \(post.title)")
                    }
                    if post.videoData != nil {
                        Button("Watch video", systemImage: "play.rectangle.fill") {
                            showingVideo = true
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("watch-life-notebook-video")
                    }
                    Text(post.title).font(.largeTitle.bold())
                    Text(post.occurredAt, style: .date)
                        .foregroundStyle(.secondary)
                    if !post.topic.isEmpty {
                        Text(post.topic).font(.subheadline.weight(.semibold))
                    }
                    if !post.text.isEmpty {
                        Text(post.text).font(.title3)
                    }
                    if let pictograms = post.pictograms, !pictograms.isEmpty {
                        Text("Picture words").font(.headline)
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(pictograms) { pictogram in
                                    Button {
                                        store.speakStandaloneMessage(pictogram.label)
                                    } label: {
                                        VStack(spacing: 8) {
                                            if let data = pictogram.imageData {
                                                AsyncThumbnailImage(data: data, maxPixelSize: 240,
                                                                    contentMode: .fit) {
                                                    Text(pictogram.symbol.isEmpty ? "💬" : pictogram.symbol)
                                                        .font(.system(size: 54))
                                                }
                                                    .frame(width: 100, height: 100)
                                            } else {
                                                Text(pictogram.symbol.isEmpty ? "💬" : pictogram.symbol)
                                                    .font(.system(size: 54))
                                                    .frame(width: 100, height: 100)
                                            }
                                            Text(pictogram.label)
                                                .font(.headline)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .frame(width: 120)
                                        }
                                        .frame(width: 132)
                                        .frame(minHeight: 158)
                                        .background(Color(uiColor: .secondarySystemBackground),
                                                    in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Speak \(pictogram.label)")
                                    .accessibilityIdentifier("life-notebook-picture-word-\(pictogram.id)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        Button("Speak picture words", systemImage: "speaker.wave.2.fill") {
                            store.speakStandaloneMessage(post.pictureWords)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("speak-life-notebook-picture-words")
                        if pictograms.contains(where: { $0.arasaacPictogramID != nil }) {
                            Text(ARASAACPictogramService.attribution)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button("Speak", systemImage: "speaker.wave.2.fill") {
                            store.speakStandaloneMessage(post.spokenText)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("speak-life-notebook-post")
                        ShareLink(item: post.sharedText) {
                            Label("Share words", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                    LifeNotebookConversationView(postID: postID, post: post)
                    Button(isExporting ? "Preparing moment…" : "Export moment file",
                           systemImage: "square.and.arrow.up.on.square") {
                        isExporting = true
                        Task {
                            defer { isExporting = false }
                            do {
                                let data = try await store.exportLifeNotebookPost(id: post.id)
                                exportDocument = BackupDocument(data: data)
                                showingExporter = true
                            } catch { transferError = error.localizedDescription }
                        }
                    }
                    .disabled(isExporting)
                    .accessibilityIdentifier("export-life-notebook-post")
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(post?.title ?? "Moment")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingVideo) {
            if let post {
                SceneHotspotVideoView(title: post.title, data: post.videoData,
                                      posterData: post.photoData)
            }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument,
                      contentType: .json, defaultFilename: exportFileName) { result in
            if case .failure(let error) = result { transferError = error.localizedDescription }
            exportDocument = nil
        }
        .alert("Moment file", isPresented: Binding(
            get: { transferError != nil }, set: { if !$0 { transferError = nil } }
        )) {
            Button("OK") { transferError = nil }
        } message: { Text(transferError ?? "") }
    }
}

private struct LifeNotebookConversationView: View {
    @EnvironmentObject private var store: CommunicationStore
    let postID: UUID
    let post: LifeNotebookPost
    @State private var speakerToAdd: LifeNotebookSpeaker?
    @State private var deletingReply: LifeNotebookReply?
    @State private var errorMessage: String?

    private var replies: [LifeNotebookReply] { post.replies ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Conversation").font(.title2.bold())
                Spacer()
                if !replies.isEmpty {
                    ShareLink(item: post.sharedConversationText) {
                        Label("Share conversation", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            if replies.isEmpty {
                Text("Ask about this moment or save a reply to talk about it later.")
                    .foregroundStyle(.secondary)
            }
            ForEach(replies) { reply in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(reply.speaker.title).font(.subheadline.bold())
                        Text(reply.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(reply.text).font(.title3)
                    HStack {
                        Button("Speak", systemImage: "speaker.wave.2.fill") {
                            store.speakStandaloneMessage(reply.text)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Speak \(reply.speaker.title) turn")
                        .accessibilityIdentifier("speak-life-notebook-reply-\(reply.id)")
                        if !store.isBoardOnlyModeActive {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                deletingReply = reply
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Delete \(reply.speaker.title) turn")
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 14))
            }
            HStack {
                Button("Add my reply", systemImage: "bubble.left.fill") {
                    speakerToAdd = .communicator
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("add-life-notebook-my-reply")
                Button("Ask a question", systemImage: "bubble.right") {
                    speakerToAdd = .partner
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("add-life-notebook-partner-question")
            }
        }
        .sheet(item: $speakerToAdd) { speaker in
            LifeNotebookReplyEditorView(postID: postID, speaker: speaker)
        }
        .confirmationDialog("Delete this turn?", isPresented: Binding(
            get: { deletingReply != nil }, set: { if !$0 { deletingReply = nil } }
        )) {
            Button("Delete turn", role: .destructive) {
                guard let reply = deletingReply else { return }
                deletingReply = nil
                Task {
                    do { try await store.deleteLifeNotebookReply(postID: postID, replyID: reply.id) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
        }
        .alert("Conversation", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

private struct LifeNotebookReplyEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    let speaker: LifeNotebookSpeaker
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !isSaving && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 500
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(speaker == .communicator ? "My reply" : "Partner question") {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Conversation turn")
                        .accessibilityIdentifier("life-notebook-reply-text")
                    Text("\(text.count) of 500 characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if speaker == .communicator &&
                   (!store.composedMessage.isEmpty || !store.typedMessage.isEmpty) {
                    Section("Use a message I made") {
                        if !store.composedMessage.isEmpty {
                            Button("Use picture message") { text = store.composedMessage }
                        }
                        if !store.typedMessage.isEmpty {
                            Button("Use typed message") { text = store.typedMessage }
                        }
                    }
                }
                Text("This turn stays with the moment, its backups, and exported moment files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(speaker == .communicator ? "My reply" : "Partner question")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                try await store.addLifeNotebookReply(postID: postID,
                                                                     speaker: speaker, text: text)
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-life-notebook-reply")
                }
            }
            .alert("Could not save turn", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

private struct LifeNotebookEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let post: LifeNotebookPost?
    @State private var title: String
    @State private var topic: String
    @State private var text: String
    @State private var occurredAt: Date
    @State private var photoData: Data?
    @State private var videoData: Data?
    @State private var pictograms: [LifeNotebookPictogram]
    @State private var newPictureWord = ""
    @State private var newPictureSymbol = ""
    @State private var showingButtonPictures = false
    @State private var showingARASAAC = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showingVideoImporter = false
    @State private var preparingVideo = false
    @State private var preparingPictogram = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(post: LifeNotebookPost?) {
        self.post = post
        _title = State(initialValue: post?.title ?? "")
        _topic = State(initialValue: post?.topic ?? "")
        _text = State(initialValue: post?.text ?? "")
        _occurredAt = State(initialValue: post?.occurredAt ?? .now)
        _photoData = State(initialValue: post?.photoData)
        _videoData = State(initialValue: post?.videoData)
        _pictograms = State(initialValue: post?.pictograms ?? [])
    }

    private var canSave: Bool {
        !isSaving && !preparingVideo && !preparingPictogram &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil ||
         !pictograms.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Moment") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("life-notebook-title")
                    TextField("Topic or person (optional)", text: $topic)
                        .accessibilityIdentifier("life-notebook-topic")
                    DatePicker("When", selection: $occurredAt, displayedComponents: .date)
                }
                Section("Photo or video") {
                    if let photoData {
                        AsyncThumbnailImage(data: photoData, maxPixelSize: 500, contentMode: .fit) {
                            Color(uiColor: .secondarySystemBackground)
                        }
                            .frame(maxHeight: 240)
                            .accessibilityLabel(videoData == nil ? "Moment photo" : "Moment video preview")
                        if videoData != nil {
                            Label("Video attached", systemImage: "play.rectangle.fill")
                            Button("Keep frame as photo") { videoData = nil }
                        } else {
                            Button("Remove photo", role: .destructive) { self.photoData = nil }
                        }
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoData == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                    }
                    .accessibilityIdentifier("life-notebook-choose-photo")
                    .disabled(preparingVideo)
                    CameraPhotoButton(title: "Take photo", identifier: "life-notebook-take-photo") {
                        photoData = $0
                        videoData = nil
                    }
                    .disabled(preparingVideo)
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("Choose video from Photos", systemImage: "video")
                    }
                    .disabled(preparingVideo)
                    Button("Choose video from Files", systemImage: "film") {
                        showingVideoImporter = true
                    }
                    .accessibilityIdentifier("life-notebook-choose-video-file")
                    .disabled(preparingVideo)
                    if preparingVideo { ProgressView("Preparing video…") }
                }
                Section("Picture words (\(pictograms.count) of 8)") {
                    ForEach($pictograms) { $pictogram in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                if let data = pictogram.imageData {
                                    AsyncThumbnailImage(data: data, maxPixelSize: 120, contentMode: .fit) {
                                        Text(pictogram.symbol.isEmpty ? "💬" : pictogram.symbol)
                                            .font(.title)
                                    }
                                        .frame(width: 52, height: 52)
                                } else {
                                    Text(pictogram.symbol.isEmpty ? "💬" : pictogram.symbol)
                                        .font(.title)
                                        .frame(width: 52, height: 52)
                                }
                                TextField("Picture word", text: $pictogram.label)
                                    .accessibilityIdentifier("life-notebook-picture-label-\(pictogram.id)")
                                TextField("Emoji", text: $pictogram.symbol)
                                    .frame(width: 72)
                                    .accessibilityLabel("Emoji for \(pictogram.label)")
                            }
                            HStack {
                                Button("Move up", systemImage: "arrow.up") {
                                    movePictogram(id: pictogram.id, by: -1)
                                }
                                .disabled(pictograms.first?.id == pictogram.id)
                                Button("Move down", systemImage: "arrow.down") {
                                    movePictogram(id: pictogram.id, by: 1)
                                }
                                .disabled(pictograms.last?.id == pictogram.id)
                                Spacer()
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    pictograms.removeAll { $0.id == pictogram.id }
                                }
                            }
                            .labelStyle(.iconOnly)
                        }
                    }
                    if pictograms.count < 8 {
                        Button("Add from picture buttons", systemImage: "square.grid.2x2") {
                            showingButtonPictures = true
                        }
                        .disabled(preparingPictogram)
                        .accessibilityIdentifier("life-notebook-add-button-picture")
                        PictureLibraryPickerButton(title: "Add from picture library",
                            identifier: "life-notebook-add-library-picture") { picture in
                            addPictogram(label: picture.title, rawImage: picture.imageData)
                        }
                        .disabled(preparingPictogram)
                        TextField("Word or short phrase", text: $newPictureWord)
                            .accessibilityIdentifier("life-notebook-new-picture-word")
                        TextField("Emoji (optional)", text: $newPictureSymbol)
                        Button("Add picture word", systemImage: "plus") {
                            addPictogram(label: newPictureWord, symbol: newPictureSymbol)
                        }
                        .disabled(preparingPictogram ||
                                  newPictureWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("life-notebook-add-picture-word")
                        Button("Find ARASAAC pictogram", systemImage: "photo.on.rectangle.angled") {
                            showingARASAAC = true
                        }
                        .disabled(preparingPictogram ||
                                  newPictureWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if preparingPictogram { ProgressView("Preparing picture word…") }
                    }
                    Text("Tap picture words in the moment to speak them one at a time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("What happened") {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Moment caption")
                        .accessibilityIdentifier("life-notebook-caption")
                }
            }
            .navigationTitle(post == nil ? "New moment" : "Edit moment")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        var updated = post ?? LifeNotebookPost(title: title)
                        updated.title = title
                        updated.topic = topic
                        updated.text = text
                        updated.occurredAt = occurredAt
                        updated.photoData = photoData
                        updated.videoData = videoData
                        updated.pictograms = pictograms
                        isSaving = true
                        Task {
                            defer { isSaving = false }
                            do {
                                try await store.saveLifeNotebookPost(updated)
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("save-life-notebook-post")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self),
                              let prepared = await PhotoProcessing.preparedDataAsync(from: data) else {
                            throw LifeNotebookError.invalidPost
                        }
                        photoData = prepared
                        videoData = nil
                    } catch { errorMessage = error.localizedDescription }
                }
            }
            .onChange(of: selectedVideo) { _, video in
                guard let video else { return }
                preparingVideo = true
                Task {
                    do {
                        guard let file = try await video.loadTransferable(type: SceneVideoFile.self) else {
                            throw SceneVideoError.unusableVideo
                        }
                        defer { try? FileManager.default.removeItem(at: file.url) }
                        await prepareVideo(from: file.url)
                    } catch {
                        preparingVideo = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .fileImporter(isPresented: $showingVideoImporter, allowedContentTypes: [.movie]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    preparingVideo = true
                    Task {
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        await prepareVideo(from: url)
                    }
                } catch {
                    errorMessage = "Could not open that video. Choose another clip."
                }
            }
            .sheet(isPresented: $showingButtonPictures) {
                LifeNotebookButtonPicturePicker { item in
                    addPictogram(label: store.displayLabel(for: item), symbol: item.symbol,
                                 rawImage: item.imageData,
                                 arasaacID: item.imageData == nil ? nil : item.arasaacPictogramID)
                    showingButtonPictures = false
                }
            }
            .sheet(isPresented: $showingARASAAC) {
                ARASAACPictogramSearchView(initialQuery: newPictureWord,
                    language: store.settings.communicationLanguage) { data, id in
                    addPictogram(label: newPictureWord, rawImage: data, arasaacID: id)
                    showingARASAAC = false
                }
            }
            .alert("Could not save moment", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func prepareVideo(from url: URL) async {
        defer { preparingVideo = false }
        do {
            let prepared = try await SceneVideoProcessing.prepared(from: url,
                byteLimit: 8 * 1_048_576)
            photoData = prepared.poster
            videoData = prepared.video
        } catch { errorMessage = error.localizedDescription }
    }

    private func movePictogram(id: UUID, by offset: Int) {
        guard let index = pictograms.firstIndex(where: { $0.id == id }),
              pictograms.indices.contains(index + offset) else { return }
        pictograms.swapAt(index, index + offset)
    }

    private func addPictogram(label: String, symbol: String = "", rawImage: Data? = nil,
                              arasaacID: Int? = nil) {
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preparingPictogram, pictograms.count < 8, !cleanLabel.isEmpty, cleanLabel.count <= 40,
              symbol.count <= 12 else {
            errorMessage = LifeNotebookError.invalidPost.localizedDescription
            return
        }
        if let rawImage {
            preparingPictogram = true
            Task {
                defer { preparingPictogram = false }
                guard let prepared = await PhotoProcessing.preparedDataAsync(from: rawImage,
                                                                            maxPixelSize: 320),
                      prepared.count <= 512 * 1_024, pictograms.count < 8 else {
                    errorMessage = LifeNotebookError.invalidPost.localizedDescription
                    return
                }
                appendPictogram(label: cleanLabel, symbol: symbol, image: prepared,
                                arasaacID: arasaacID)
            }
        } else {
            appendPictogram(label: cleanLabel, symbol: symbol, image: nil, arasaacID: arasaacID)
        }
    }

    private func appendPictogram(label: String, symbol: String, image: Data?, arasaacID: Int?) {
        pictograms.append(LifeNotebookPictogram(label: label, symbol: symbol,
            imageData: image, arasaacPictogramID: arasaacID))
        if newPictureWord == label { newPictureWord = "" }
        if newPictureSymbol == symbol { newPictureSymbol = "" }
    }
}

private struct LifeNotebookButtonPicturePicker: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let onSelect: (CommunicationItem) -> Void

    private var availableItems: [CommunicationItem] {
        store.items.filter { item in
            item.effectiveAction == .addToMessage && item.boardVisibility != .hidden &&
            (item.imageData != nil || !item.symbol.isEmpty) &&
            (search.isEmpty || store.displayLabel(for: item).localizedStandardContains(search))
        }.sorted {
            store.displayLabel(for: $0).localizedStandardCompare(store.displayLabel(for: $1)) ==
                .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List(availableItems) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        if let data = item.imageData {
                            AsyncThumbnailImage(data: data, maxPixelSize: 100, contentMode: .fit) {
                                Text(item.symbol).font(.title)
                            }
                                .frame(width: 48, height: 48)
                        } else {
                            Text(item.symbol).font(.title).frame(width: 48, height: 48)
                        }
                        Text(store.displayLabel(for: item))
                    }
                }
                .accessibilityIdentifier("life-notebook-button-option-\(item.id)")
            }
            .searchable(text: $search, prompt: "Find a picture button")
            .navigationTitle("Picture buttons")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
