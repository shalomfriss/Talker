import AVFoundation
import SwiftUI

private enum StorySwitchAssignment {
    case read
    case advance
}

struct StoryReaderView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.scenePhase) private var scenePhase
    let storyID: UUID
    @State private var pageIndex = 0
    @State private var showingAddPage = false
    @State private var editingPage: StoryPage?
    @State private var playingPage: StoryPage?
    @State private var storyPDF: Data?
    @State private var hasStartedOneTap = false
    @State private var slideshowTask: Task<Void, Never>?
    @State private var isSlideshowPlaying = false
    @State private var branchHistory: [UUID] = []
    @State private var showingSwitchKeySettings = false
    @State private var capturingSwitchAssignment: StorySwitchAssignment?

    private var story: VisualStory? { store.stories.first { $0.id == storyID } }
    private var storySwitchChoices: [StorySwitchKey] {
        var choices = StorySwitchKey.allCases
        for key in [store.settings.storyReadKey, store.settings.storyAdvanceKey] where !choices.contains(key) {
            choices.append(key)
        }
        return choices
    }

    var body: some View {
        Group {
            if let story {
                if story.pages.isEmpty {
                    ContentUnavailableView {
                        Label("No pages yet", systemImage: "book.closed")
                    } description: {
                        Text("Add a photo and a few words to begin.")
                    } actions: {
                        Button("Add first page") { showingAddPage = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    let safeIndex = min(pageIndex, story.pages.count - 1)
                    let page = story.pages[safeIndex]
                    let pageChoices = StoryChoice.cleaned(page.choices,
                        validTargets: Set(story.pages.map(\.id)).subtracting([page.id]))
                    let oneTap = store.settings.storyOneTapReading
                    let twoSwitch = store.settings.storyTwoSwitchReading
                    VStack(spacing: 20) {
                        Toggle("One-tap reading", isOn: Binding(
                            get: { store.settings.storyOneTapReading },
                            set: { enabled in
                                stopSlideshow()
                                store.stopSpeaking()
                                hasStartedOneTap = false
                                if enabled { store.settings.storyTwoSwitchReading = false }
                                store.settings.storyOneTapReading = enabled
                            }
                        ))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("story-one-tap-toggle")
                        Toggle("Two-switch reading", isOn: Binding(
                            get: { store.settings.storyTwoSwitchReading },
                            set: { enabled in
                                stopSlideshow()
                                store.stopSpeaking()
                                hasStartedOneTap = false
                                if enabled { store.settings.storyOneTapReading = false }
                                store.settings.storyTwoSwitchReading = enabled
                            }
                        ))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("story-two-switch-toggle")
                        if oneTap || twoSwitch {
                            Button("Keyboard switch keys", systemImage: "keyboard") {
                                showingSwitchKeySettings = true
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal, 24)
                            .accessibilityIdentifier("story-switch-keys")
                        }
                        HStack(spacing: 12) {
                            Button {
                                if isSlideshowPlaying { stopSlideshow() }
                                else { startSlideshow() }
                            } label: {
                                Label(isSlideshowPlaying ? "Pause slideshow" : "Play slideshow",
                                      systemImage: isSlideshowPlaying ? "pause.fill" : "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("story-slideshow-play")
                            Menu {
                                ForEach([0.0, 1.0, 3.0, 5.0], id: \.self) { seconds in
                                    Button(seconds == 0 ? "No pause" : "\(Int(seconds)) second pause") {
                                        store.settings.storySlideshowPause = seconds
                                    }
                                }
                            } label: {
                                Label("Page pause: \(Int(store.settings.storySlideshowPause)) s",
                                      systemImage: "timer")
                            }
                            .accessibilityIdentifier("story-slideshow-pause")
                        }
                        .controlSize(.large)
                        .padding(.horizontal, 24)
                        ScrollView {
                            VStack(spacing: 4) {
                                if oneTap && page.videoData == nil {
                                    Button(action: activateOneTap) {
                                        pageContent(page)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Story page. \(page.text)")
                                    .accessibilityValue(storySpeechValue(for: page))
                                    .accessibilityHint("Read or advance and read")
                                    .accessibilityIdentifier("story-page-tap")
                                } else {
                                    pageContent(page)
                                }
                                if !pageChoices.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("What happens next?")
                                            .font(.headline)
                                        ForEach(pageChoices) { choice in
                                            Button {
                                                followChoice(choice, from: page, in: story)
                                            } label: {
                                                Label(choice.label, systemImage: "arrow.turn.down.right")
                                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .accessibilityIdentifier("story-choice-\(choice.id)")
                                        }
                                    }
                                    .frame(maxWidth: 620)
                                    .padding(.horizontal, 24)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if oneTap {
                            Text("Tap the page or use the large button to read and advance. Press \(store.settings.storyAdvanceKey.title) on a keyboard switch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else if twoSwitch {
                            Text("\(store.settings.storyReadKey.title) reads this page. \(store.settings.storyAdvanceKey.title) moves to the next page.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        if twoSwitch {
                            HStack(spacing: 12) {
                                Button {
                                    stopSlideshow()
                                    store.readStoryPage(storyID: storyID, pageID: page.id)
                                } label: {
                                    Label("Read", systemImage: page.audioData == nil
                                          ? "speaker.wave.2.fill" : "waveform")
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(store.settings.storyReadKey.keyEquivalent, modifiers: [])
                                .accessibilityLabel("Read current page")
                                .accessibilityIdentifier("story-read-page")
                                .accessibilityHint("Press \(store.settings.storyReadKey.title) to read this page")
                                Button {
                                    movePage(to: safeIndex + 1)
                                } label: {
                                    Label("Next", systemImage: "arrow.right")
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                }
                                .buttonStyle(.bordered)
                                .disabled(safeIndex == story.pages.count - 1)
                                .keyboardShortcut(store.settings.storyAdvanceKey.keyEquivalent, modifiers: [])
                                .accessibilityLabel("Next page")
                                .accessibilityIdentifier("story-switch-next-page")
                                .accessibilityHint("Press \(store.settings.storyAdvanceKey.title) to move without reading")
                            }
                            .controlSize(.large)
                            .padding(.horizontal, 24)
                        } else {
                            Button {
                                if oneTap { activateOneTap() }
                                else {
                                    stopSlideshow()
                                    store.readStoryPage(storyID: storyID, pageID: page.id)
                                }
                            } label: {
                                Label(oneTap
                                      ? (hasStartedOneTap
                                         ? (!pageChoices.isEmpty ? "Read this page again"
                                            : (safeIndex < story.pages.count - 1 ? "Next and read" : "Read last page again"))
                                         : (page.audioData == nil ? "Read this page" : "Play this page"))
                                      : (page.audioData == nil ? "Read this page" : "Play recorded narration"),
                                      systemImage: page.audioData == nil ? "speaker.wave.2.fill" : "waveform")
                                    .frame(maxWidth: oneTap ? .infinity : nil,
                                           minHeight: oneTap ? 64 : nil)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.horizontal, oneTap ? 24 : 0)
                            .keyboardShortcut(oneTap ? store.settings.storyAdvanceKey.keyEquivalent : .return,
                                              modifiers: [])
                            .accessibilityIdentifier("story-read-page")
                            .accessibilityHint(oneTap
                                ? "Tap or press \(store.settings.storyAdvanceKey.title) to read and advance"
                                : (page.audioData == nil ? "Read with the system voice" : "Play recorded narration"))
                        }
                        if page.audioData != nil {
                            Button("Read with highlighting", systemImage: "text.magnifyingglass") {
                                stopSlideshow()
                                store.readStoryPage(storyID: storyID, pageID: page.id,
                                                    usingSystemVoice: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityHint("Use the system voice and highlight words as they are spoken")
                            .accessibilityIdentifier("story-read-highlighted")
                        }
                        HStack {
                            Button("Previous", systemImage: "arrow.left") {
                                if branchHistory.isEmpty { movePage(to: safeIndex - 1) }
                                else { returnFromChoice(in: story) }
                            }
                                .disabled(safeIndex == 0 && branchHistory.isEmpty)
                            Spacer()
                            Text("\(safeIndex + 1) of \(story.pages.count)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Next", systemImage: "arrow.right") { movePage(to: safeIndex + 1) }
                                .disabled(safeIndex == story.pages.count - 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Edit page", systemImage: "pencil") {
                                stopSlideshow()
                                editingPage = page
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Story not found", systemImage: "book.closed")
            }
        }
        .navigationTitle(story?.title ?? "Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add page", systemImage: "plus") {
                    stopSlideshow()
                    showingAddPage = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Preview story PDF", systemImage: "doc.richtext") {
                    if let story { storyPDF = PrintableStoryPDF.makeData(story: story) }
                }
                .disabled(story?.pages.isEmpty ?? true)
                .accessibilityIdentifier("story-preview-pdf")
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: story?.shareText ?? "") {
                    Label("Share story text", systemImage: "square.and.arrow.up")
                }
                .disabled(story?.pages.isEmpty ?? true)
                .accessibilityIdentifier("story-share-text")
            }
        }
        .sheet(isPresented: $showingAddPage) { StoryPageEditorView(storyID: storyID, page: nil) }
        .sheet(item: $editingPage) { StoryPageEditorView(storyID: storyID, page: $0) }
        .sheet(item: $playingPage) { SceneHotspotVideoView(page: $0) }
        .sheet(isPresented: $showingSwitchKeySettings) {
            NavigationStack {
                Group {
                    if let assignment = capturingSwitchAssignment {
                        StorySwitchKeyCaptureView(
                            actionName: assignment == .read ? "Read" :
                                (store.settings.storyOneTapReading ? "Read and advance" : "Next page")) { key in
                            if assignment == .read { store.settings.selectStoryReadKey(key) }
                            else { store.settings.selectStoryAdvanceKey(key) }
                            capturingSwitchAssignment = nil
                        } onCancel: {
                            capturingSwitchAssignment = nil
                        }
                    } else {
                        Form {
                            if store.settings.storyTwoSwitchReading {
                                Picker("Read key", selection: Binding(
                                    get: { store.settings.storyReadKey },
                                    set: { store.settings.selectStoryReadKey($0) }
                                )) {
                                    ForEach(storySwitchChoices) { key in
                                        Text(key.title).tag(key)
                                    }
                                }
                                .accessibilityIdentifier("story-read-key")
                                Button("Press switch to set Read key", systemImage: "keyboard.badge.ellipsis") {
                                    capturingSwitchAssignment = .read
                                }
                                .accessibilityIdentifier("story-capture-read-key")
                            }
                            Picker(store.settings.storyOneTapReading ? "Read and advance key" : "Next page key",
                                   selection: Binding(
                                    get: { store.settings.storyAdvanceKey },
                                    set: { store.settings.selectStoryAdvanceKey($0) }
                                   )) {
                                ForEach(storySwitchChoices) { key in
                                    Text(key.title).tag(key)
                                }
                            }
                            .accessibilityIdentifier("story-advance-key")
                            Button(store.settings.storyOneTapReading
                                   ? "Press switch to set Read and advance key"
                                   : "Press switch to set Next page key",
                                   systemImage: "keyboard.badge.ellipsis") {
                                capturingSwitchAssignment = .advance
                            }
                            .accessibilityIdentifier("story-capture-advance-key")
                            Text("Press an unmodified key sent by a paired keyboard switch, or choose a common key above. Using the other story action's key swaps the assignments.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle(capturingSwitchAssignment == nil ? "Keyboard switch keys" : "Press a key")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            capturingSwitchAssignment = nil
                            showingSwitchKeySettings = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { storyPDF != nil }, set: { if !$0 { storyPDF = nil } }
        )) {
            if let storyPDF {
                PrintableBoardsPreview(data: storyPDF, title: "Printable story",
                                       filename: "Open Voice Story")
            }
        }
        .onDisappear {
            stopSlideshow()
            store.stopSpeaking()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopSlideshow() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            stopSlideshow()
        }
    }

    private func activateOneTap() {
        stopSlideshow()
        guard let story, !story.pages.isEmpty else { return }
        let current = min(pageIndex, story.pages.count - 1)
        if hasStartedOneTap && story.pages[current].choices.isEmpty && current + 1 < story.pages.count {
            movePage(to: current + 1, read: true)
        } else {
            store.readStoryPage(storyID: storyID, pageID: story.pages[current].id)
            hasStartedOneTap = true
        }
    }

    @ViewBuilder
    private func pageContent(_ page: StoryPage) -> some View {
        let photos = page.photos
        let textPanel = page.backgroundStyle == .photo ? Color.white.opacity(0.88) : Color.clear
        VStack(spacing: 24) {
            if page.videoData != nil {
                Button {
                    stopSlideshow()
                    store.stopSpeaking()
                    playingPage = page
                } label: {
                    Group {
                        if let poster = page.videoPosterData {
                            AsyncThumbnailImage(data: poster, maxPixelSize: 900, contentMode: .fit) {
                                Text(page.symbol).font(.system(size: 100))
                            }
                            .frame(maxHeight: 360)
                        } else {
                            Text(page.symbol).font(.system(size: 100))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play page video")
                .accessibilityIdentifier("story-play-video")
            } else if photos.count == 3 {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        photoTile(photos[0], height: 150)
                        photoTile(photos[1], height: 150)
                    }
                    photoTile(photos[2], height: 150)
                }
                .frame(maxWidth: 680)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Three photos on this page")
                .accessibilityIdentifier("story-photo-grid")
            } else if photos.count > 1 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(photos.indices, id: \.self) { index in
                        photoTile(photos[index], height: photos.count > 2 ? 150 : 220)
                    }
                }
                .frame(maxWidth: 680)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(photos.count) photos on this page")
                .accessibilityIdentifier("story-photo-grid")
            } else if let data = photos.first {
                AsyncThumbnailImage(data: data, maxPixelSize: 900, contentMode: .fit) {
                    Text(page.symbol).font(.system(size: 100))
                }
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
            } else {
                Text(page.symbol)
                    .font(.system(size: 100))
                    .accessibilityHidden(true)
            }
            if let highlight = store.speechHighlight,
               highlight.source == .story(storyID: storyID, pageID: page.id) {
                SpeechFollowAlongView(state: highlight)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(textPanel, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("story-follow-along")
                    .accessibilityValue(highlight.currentUnit.map { "Now speaking: \($0)" }
                        ?? "Preparing speech")
            } else {
                Text(page.text)
                    .font(.title.weight(.medium))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(textPanel, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .frame(maxWidth: 900)
        .background {
            if page.backgroundStyle != .plain {
                StoryPageBackgroundView(style: page.backgroundStyle,
                                        photoData: page.backgroundPhotoData)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func photoTile(_ data: Data, height: CGFloat) -> some View {
        GeometryReader { geometry in
            AsyncThumbnailImage(data: data, maxPixelSize: 500) {
                Color(uiColor: .secondarySystemBackground)
            }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }

    private func storySpeechValue(for page: StoryPage) -> String {
        guard let highlight = store.speechHighlight,
              highlight.source == .story(storyID: storyID, pageID: page.id) else { return "" }
        return highlight.currentUnit.map { "Now speaking: \($0)" } ?? "Preparing speech"
    }

    private func movePage(to index: Int, read: Bool = false) {
        guard let story, story.pages.indices.contains(index) else { return }
        stopSlideshow()
        store.stopSpeaking()
        pageIndex = index
        branchHistory = []
        hasStartedOneTap = read
        if read { store.readStoryPage(storyID: storyID, pageID: story.pages[index].id) }
    }

    private func followChoice(_ choice: StoryChoice, from page: StoryPage, in story: VisualStory) {
        guard let targetIndex = story.pages.firstIndex(where: { $0.id == choice.targetPageID }),
              choice.targetPageID != page.id else { return }
        stopSlideshow()
        store.stopSpeaking()
        branchHistory.append(page.id)
        pageIndex = targetIndex
        hasStartedOneTap = false
        store.readStoryPage(storyID: storyID, pageID: choice.targetPageID)
    }

    private func returnFromChoice(in story: VisualStory) {
        while let previousID = branchHistory.popLast() {
            guard let index = story.pages.firstIndex(where: { $0.id == previousID }) else { continue }
            stopSlideshow()
            store.stopSpeaking()
            pageIndex = index
            hasStartedOneTap = false
            return
        }
    }

    private func startSlideshow() {
        guard let story, !story.pages.isEmpty else { return }
        stopSlideshow()
        store.settings.storyOneTapReading = false
        store.settings.storyTwoSwitchReading = false
        hasStartedOneTap = false
        isSlideshowPlaying = true
        slideshowTask = Task { @MainActor in
            while !Task.isCancelled, let currentStory = storyForSlideshow,
                  currentStory.pages.indices.contains(pageIndex) {
                let currentIndex = pageIndex
                guard let playbackID = store.readStoryPage(
                    storyID: storyID, pageID: currentStory.pages[currentIndex].id) else { break }
                while !Task.isCancelled, store.completedStoryPlaybackID != playbackID,
                      store.activeStoryPlaybackID == playbackID {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                guard !Task.isCancelled, store.completedStoryPlaybackID == playbackID else { break }
                let pause = store.settings.storySlideshowPause
                if pause > 0 { try? await Task.sleep(for: .seconds(pause)) }
                guard !Task.isCancelled, let updatedStory = storyForSlideshow,
                      updatedStory.pages.indices.contains(currentIndex),
                      pageIndex == currentIndex else { break }
                if !updatedStory.pages[currentIndex].choices.isEmpty { break }
                if currentIndex + 1 >= updatedStory.pages.count { break }
                store.stopSpeaking()
                pageIndex = currentIndex + 1
            }
            if !Task.isCancelled {
                isSlideshowPlaying = false
                slideshowTask = nil
            }
        }
    }

    private var storyForSlideshow: VisualStory? { store.stories.first { $0.id == storyID } }

    private func stopSlideshow() {
        slideshowTask?.cancel()
        slideshowTask = nil
        if isSlideshowPlaying { store.stopSpeaking() }
        isSlideshowPlaying = false
    }
}

private extension StorySwitchKey {
    var keyEquivalent: KeyEquivalent {
        switch rawValue {
        case Self.space.rawValue: .space
        case Self.returnKey.rawValue: .return
        case Self.rightArrow.rawValue: .rightArrow
        case Self.leftArrow.rawValue: .leftArrow
        case Self.n.rawValue: KeyEquivalent("n")
        case Self.r.rawValue: KeyEquivalent("r")
        default: customCharacter.map { KeyEquivalent($0) } ?? .space
        }
    }

    static func captured(_ key: KeyEquivalent) -> StorySwitchKey? {
        if key == .space { return .space }
        if key == .return { return .returnKey }
        if key == .rightArrow { return .rightArrow }
        if key == .leftArrow { return .leftArrow }
        if key == KeyEquivalent("n") { return .n }
        if key == KeyEquivalent("r") { return .r }
        return captured(key.character)
    }
}

private struct StorySwitchKeyCaptureView: View {
    let actionName: String
    let onCapture: (StorySwitchKey) -> Void
    let onCancel: () -> Void
    @FocusState private var hasKeyboardFocus: Bool
    @State private var typedKey = ""
    @State private var hasCaptured = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Press the switch key for \(actionName)")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("Press one key without Command, Control, Option, or Shift. The key will be saved when received.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("Waiting for a key…", text: $typedKey)
                .font(.headline)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .focused($hasKeyboardFocus)
                .onChange(of: typedKey) { _, value in
                    guard let character = value.first else { return }
                    if character == " " { capture(.space) }
                    else if let key = StorySwitchKey.captured(character) { capture(key) }
                }
                .onKeyPress(phases: [.down]) { press in
                    guard press.modifiers.isEmpty,
                          let key = StorySwitchKey.captured(press.key) else { return .handled }
                    capture(key)
                    return .handled
                }
                .onSubmit { capture(.returnKey) }
                .accessibilityIdentifier("story-key-capture-target")
            Button("Cancel", action: onCancel)
        }
        .padding(24)
        .task {
            await Task.yield()
            hasKeyboardFocus = true
        }
    }

    private func capture(_ key: StorySwitchKey) {
        guard !hasCaptured else { return }
        hasCaptured = true
        onCapture(key)
    }
}
