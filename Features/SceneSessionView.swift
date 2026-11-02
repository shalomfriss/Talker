import AVFoundation
import SwiftUI

private enum SceneScanTarget: Equatable {
    case hotspot(UUID)
    case labelMode(SceneLabelMode)
    case playPauseVideo
    case replayVideo
    case previousScene
    case speakMessage
    case returnToSpeak
    case done
}

struct SceneSessionView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let board: VisualSceneBoard
    let onReturnToSpeak: () -> Void
    @State private var selectedOption: ChoiceOption?
    @State private var pendingHotspot: SceneHotspot?
    @State private var selectedHotspotVideo: SceneHotspot?
    @State private var literacyCue: SceneLiteracyCue?
    @State private var repeatTapFilter = RepeatTapFilter()
    @State private var sceneHistory: [UUID] = []
    @State private var videoPlayer: AVPlayer?
    @State private var videoURL: URL?
    @State private var isVideoVisible = false
    @State private var isVideoPlaying = false
    @State private var isVisible = false
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private var currentScene: VisualSceneBoard {
        let id = sceneHistory.last ?? board.id
        return store.sceneBoards.first(where: { $0.id == id }) ?? board
    }

    private var pendingScene: VisualSceneBoard? {
        guard let id = pendingHotspot?.destinationSceneID else { return nil }
        return store.sceneBoards.first(where: { $0.id == id })
    }

    private var pendingDialogTitle: String {
        if pendingHotspot?.videoData != nil { return "Play attached video?" }
        if let pendingScene { return "Open \(pendingScene.title)?" }
        let label = pendingHotspot.map {
            store.displayLabel(for: $0.option.resolved(using: store.items).communicationItem)
        } ?? "this word"
        return "Choose \(label)?"
    }

    private var scanTargets: [SceneScanTarget] {
        var targets = currentScene.hotspots.map { SceneScanTarget.hotspot($0.id) }
        targets += [.labelMode(.always), .labelMode(.onTap)]
        if currentScene.isVideoScene, videoPlayer != nil {
            targets += [.playPauseVideo, .replayVideo]
        }
        if !sceneHistory.isEmpty { targets.append(.previousScene) }
        if !store.messageParts.isEmpty { targets.append(.speakMessage) }
        targets += [.returnToSpeak, .done]
        return targets
    }

    private var highlightedScanTarget: SceneScanTarget? {
        guard store.settings.scanEnabled, isVisible, pendingHotspot == nil,
              selectedHotspotVideo == nil, !scanTargets.isEmpty else { return nil }
        return scanTargets[min(scanIndex, scanTargets.count - 1)]
    }

    private var currentScanCue: ScanCue? {
        guard let highlightedScanTarget else { return nil }
        return ScanCue(text: scanLabel(for: highlightedScanTarget),
                       language: store.settings.communicationLanguage)
    }

    private var scanTimerID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanMode.rawValue)-\(store.settings.scanInterval)-\(currentScene.id)"
    }

    private var scanHighlightColor: Color { store.settings.highContrast ? .black : .orange }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            if store.settings.scanEnabled { scanControlBar }
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    Text("Tap a word to say it, or an arrow to open a related scene.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        labelModeButton(.always, title: "Always visible")
                        labelModeButton(.onTap, title: "Show on tap")
                    }
                    if currentScene.isVideoScene {
                        HStack {
                            Button(isVideoPlaying ? "Pause scene video" : "Play scene video",
                                   systemImage: isVideoPlaying ? "pause.fill" : "play.fill") {
                                toggleVideo()
                            }
                            .disabled(videoPlayer == nil)
                            .accessibilityIdentifier("scene-video-play-pause")
                            .overlay(scanOutline(for: .playPauseVideo))
                            .id("scene-scan-play-pause")
                            Button("Replay", systemImage: "gobackward") {
                                replayVideo()
                            }
                            .disabled(videoPlayer == nil)
                            .accessibilityIdentifier("scene-video-replay")
                            .overlay(scanOutline(for: .replayVideo))
                            .id("scene-scan-replay")
                            Spacer()
                        }
                        .buttonStyle(.bordered)
                    }
                    ScenePhotoCanvas(imageData: currentScene.imageData, hotspots: currentScene.hotspots,
                                     videoPlayer: isVideoVisible ? videoPlayer : nil) { hotspot, size in
                        let option = hotspot.option.resolved(using: store.items)
                        let linkedScene = hotspot.destinationSceneID.flatMap { id in
                            store.sceneBoards.first(where: { $0.id == id })
                        }
                        SceneHotspotButton(id: hotspot.id,
                                           label: store.displayLabel(for: option.communicationItem),
                                           highContrast: store.settings.highContrast,
                                           holdDuration: store.settings.wordHoldDuration,
                                           showsLabel: store.settings.sceneLabelMode == .always && hotspot.showsLabel != false,
                                           width: hotspot.width.map { $0 * size.width },
                                           height: hotspot.height.map { $0 * size.height },
                                           backgroundColorHex: hotspot.backgroundColorHex,
                                           behavior: hotspot.effectiveBehavior,
                                           hasVideo: hotspot.videoData != nil,
                                           linkedSceneTitle: linkedScene?.title,
                                           isScanHighlighted: highlightedScanTarget == .hotspot(hotspot.id)) {
                            choose(hotspot)
                        }
                    }
                    .id("scene-scan-canvas")
                    .overlay {
                        GeometryReader { geometry in
                            if let literacyCue {
                                let width = min(300, max(0, geometry.size.width - 32))
                                let halfWidth = width / 2 + 8
                                let cueY = literacyCue.y < 0.3
                                    ? literacyCue.y * geometry.size.height + 66
                                    : literacyCue.y * geometry.size.height - 66
                                Text(literacyCue.text)
                                    .font(.title.bold())
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: width)
                                    .background(.black, in: RoundedRectangle(cornerRadius: 14))
                                    .position(x: min(max(literacyCue.x * geometry.size.width, halfWidth),
                                                     geometry.size.width - halfWidth),
                                              y: min(max(cueY, 42), geometry.size.height - 42))
                                    .transition(.offset(y: 12).combined(with: .opacity))
                                    .accessibilityIdentifier("scene-literacy-word")
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    if let selectedOption {
                        Text("Selected: \(store.displayLabel(for: selectedOption.communicationItem))")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("scene-selected-word")
                    }
                    if !sceneHistory.isEmpty {
                        Button("Back to previous scene", systemImage: "chevron.left") {
                            sceneHistory.removeLast()
                            selectedOption = nil
                            literacyCue = nil
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("scene-back")
                        .overlay(scanOutline(for: .previousScene))
                        .id("scene-scan-previous")
                    }
                    if !store.messageParts.isEmpty {
                        Text(store.composedMessage)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        Button("Speak message", systemImage: "speaker.wave.2") { store.speakMessage() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("scene-speak-message")
                            .overlay(scanOutline(for: .speakMessage))
                            .id("scene-scan-speak-message")
                    }
                    Button("Back to full Speak board", systemImage: "square.grid.2x2") { onReturnToSpeak() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("scene-return-to-speak")
                        .overlay(scanOutline(for: .returnToSpeak))
                        .id("scene-scan-return-to-speak")
                }
                .padding()
            }
            .onChange(of: highlightedScanTarget) { _, target in
                if let target, let identifier = scanScrollID(for: target) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo(identifier, anchor: .center)
                    }
                }
            }
            }
            }
            .navigationTitle(currentScene.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("scene-done")
                    .overlay(scanOutline(for: .done))
            } }
            .confirmationDialog(pendingDialogTitle, isPresented: Binding(
                get: { pendingHotspot != nil }, set: { if !$0 { pendingHotspot = nil } }
            )) {
                Button(pendingHotspot?.videoData != nil ? "Play video" :
                       (pendingScene == nil ? "Choose" : "Open scene")) {
                    if let pendingHotspot { commit(pendingHotspot) }
                    pendingHotspot = nil
                }
                Button("Cancel", role: .cancel) { pendingHotspot = nil }
            }
            .task(id: currentScene.id) { prepareCurrentVideo() }
            .task(id: scanTimerID) { await runScanTimer() }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; clearVideo(); store.stopScanCue() }
            .onChange(of: currentScanCue, initial: true) { _, cue in
                if let cue { store.previewScanCue(cue) }
                else { store.stopScanCue() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
                if let item = note.object as? AVPlayerItem, item === videoPlayer?.currentItem {
                    isVideoPlaying = false
                }
            }
            .sheet(item: $selectedHotspotVideo) { hotspot in
                SceneHotspotVideoView(hotspot: hotspot)
            }
        }
    }

    private func prepareCurrentVideo() {
        clearVideo()
        guard let data = currentScene.videoData else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        do {
            try data.write(to: url, options: .atomic)
            videoURL = url
            videoPlayer = AVPlayer(url: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func toggleVideo() {
        guard let videoPlayer else { return }
        if isVideoPlaying {
            videoPlayer.pause()
            isVideoPlaying = false
        } else {
            isVideoVisible = true
            if videoPlayer.currentItem?.currentTime() == videoPlayer.currentItem?.duration {
                videoPlayer.seek(to: .zero)
            }
            videoPlayer.play()
            isVideoPlaying = true
        }
    }

    private func replayVideo() {
        guard let videoPlayer else { return }
        videoPlayer.seek(to: .zero)
        isVideoVisible = true
        videoPlayer.play()
        isVideoPlaying = true
    }

    private func clearVideo() {
        videoPlayer?.pause()
        videoPlayer = nil
        isVideoPlaying = false
        isVideoVisible = false
        if let videoURL { try? FileManager.default.removeItem(at: videoURL) }
        videoURL = nil
    }

    private func labelModeButton(_ mode: SceneLabelMode, title: String) -> some View {
        let selected = store.settings.sceneLabelMode == mode
        return Button {
            store.settings.sceneLabelMode = mode
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.indigo : Color(uiColor: .secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scene-label-\(mode.rawValue)")
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .overlay(scanOutline(for: .labelMode(mode)))
            .id("scene-scan-label-\(mode.rawValue)")
    }

    private func scanOutline(for target: SceneScanTarget) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(highlightedScanTarget == target ? scanHighlightColor : .clear,
                          lineWidth: 4)
            .allowsHitTesting(false)
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.settings.scanMode == .step ? "STEP SCAN · PHOTO SCENE" : "AUTO SCAN · PHOTO SCENE")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No scene action")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("scene-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedTarget() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("scene-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") { scanPaused.toggle() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("scene-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("scene-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: SceneScanTarget) -> String {
        switch target {
        case .hotspot(let id):
            guard let hotspot = currentScene.hotspots.first(where: { $0.id == id }) else { return "Word" }
            let label = store.displayLabel(for: hotspot.option.resolved(using: store.items).communicationItem)
            if hotspot.videoData != nil { return "Play video for \(label)" }
            if let destination = hotspot.destinationSceneID,
               let scene = store.sceneBoards.first(where: { $0.id == destination }) {
                return "Open \(scene.title) from \(label)"
            }
            return label
        case .labelMode(.always): return "Always visible"
        case .labelMode(.onTap): return "Show on tap"
        case .playPauseVideo: return isVideoPlaying ? "Pause scene video" : "Play scene video"
        case .replayVideo: return "Replay scene video"
        case .previousScene: return "Back to previous scene"
        case .speakMessage: return "Speak message"
        case .returnToSpeak: return "Back to full Speak board"
        case .done: return "Done"
        }
    }

    private func scanScrollID(for target: SceneScanTarget) -> String? {
        switch target {
        case .hotspot: return "scene-scan-canvas"
        case .labelMode(let mode): return "scene-scan-label-\(mode.rawValue)"
        case .playPauseVideo: return "scene-scan-play-pause"
        case .replayVideo: return "scene-scan-replay"
        case .previousScene: return "scene-scan-previous"
        case .speakMessage: return "scene-scan-speak-message"
        case .returnToSpeak: return "scene-scan-return-to-speak"
        case .done: return nil
        }
    }

    private func advanceScan() {
        guard !scanTargets.isEmpty else { scanIndex = 0; return }
        scanIndex = (scanIndex + 1) % scanTargets.count
    }

    private func selectHighlightedTarget() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35,
              let target = highlightedScanTarget else { return }
        lastScanActivation = now
        switch target {
        case .hotspot(let id):
            if let hotspot = currentScene.hotspots.first(where: { $0.id == id }) { choose(hotspot) }
        case .labelMode(let mode): store.settings.sceneLabelMode = mode
        case .playPauseVideo: toggleVideo()
        case .replayVideo: replayVideo()
        case .previousScene:
            sceneHistory.removeLast()
            selectedOption = nil
            literacyCue = nil
            scanIndex = 0
        case .speakMessage: store.speakMessage()
        case .returnToSpeak: onReturnToSpeak()
        case .done: dismiss()
        }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active, isVisible, !scanPaused,
               pendingHotspot == nil, selectedHotspotVideo == nil {
                advanceScan()
            }
        }
    }

    private func choose(_ hotspot: SceneHotspot) {
        let option = hotspot.option.resolved(using: store.items)
        let repeatID = hotspot.destinationSceneID == nil && hotspot.videoData == nil ? option.id : hotspot.id
        guard repeatTapFilter.allows(repeatID, interval: store.settings.repeatFilterInterval) else { return }
        if store.settings.confirmSelection { pendingHotspot = hotspot }
        else { commit(hotspot) }
    }

    private func commit(_ hotspot: SceneHotspot) {
        videoPlayer?.pause()
        isVideoPlaying = false
        if hotspot.videoData != nil {
            selectedHotspotVideo = hotspot
            selectedOption = nil
            literacyCue = nil
            return
        }
        if let id = hotspot.destinationSceneID,
           let linkedScene = store.sceneBoards.first(where: { $0.id == id }) {
            sceneHistory.append(linkedScene.id)
            selectedOption = nil
            literacyCue = nil
            scanIndex = 0
            return
        }
        let option = hotspot.option.resolved(using: store.items)
        selectedOption = option
        var item = option.communicationItem
        if let spokenText = hotspot.spokenText {
            item.message = spokenText
            item.audioData = nil
        }
        switch hotspot.effectiveBehavior {
        case .speakAndAdd:
            store.select(item, speakFeedback: true, messageOverride: hotspot.spokenText)
            if item.audioData == nil && !store.settings.speakOnTap {
                store.speak(hotspot.spokenText ?? store.displayMessage(for: item))
            }
        case .speakOnly:
            if let audioData = item.audioData { store.playRecorded(audioData) }
            else { store.speak(hotspot.spokenText ?? store.displayMessage(for: item)) }
        case .addOnly:
            store.select(item, speakFeedback: false, messageOverride: hotspot.spokenText)
        }
        let cue = SceneLiteracyCue(text: store.displayLabel(for: item), x: hotspot.x, y: hotspot.y)
        withAnimation(.easeOut(duration: 0.25)) { literacyCue = cue }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard literacyCue?.id == cue.id else { return }
            withAnimation(.easeIn(duration: 0.25)) { literacyCue = nil }
        }
    }
}

private struct SceneLiteracyCue: Identifiable {
    let id = UUID()
    let text: String
    let x: Double
    let y: Double
}

private struct SceneHotspotButton: View {
    let id: UUID
    let label: String
    let highContrast: Bool
    let holdDuration: Double
    let showsLabel: Bool
    let width: CGFloat?
    let height: CGFloat?
    let backgroundColorHex: String?
    let behavior: SceneHotspotBehavior
    let hasVideo: Bool
    let linkedSceneTitle: String?
    let isScanHighlighted: Bool
    let action: () -> Void

    private var markerColor: Color {
        guard !highContrast, let backgroundColorHex,
              let value = ButtonColorValue(text: backgroundColorHex) else {
            return highContrast ? .black : .white.opacity(0.94)
        }
        return ButtonColorAppearance.color(value)
    }

    private var markerForeground: Color {
        guard !highContrast else { return .white }
        guard let backgroundColorHex, let value = ButtonColorValue(text: backgroundColorHex) else {
            return .indigo
        }
        return value.prefersDarkText ? .black : .white
    }

    private var button: some View {
        Button(action: action) {
            if showsLabel {
                HStack(spacing: 5) {
                    SceneMarkerLabel(label: label, highContrast: highContrast,
                                     width: width, height: height,
                                     backgroundColorHex: backgroundColorHex)
                    if linkedSceneTitle != nil || hasVideo {
                        Image(systemName: hasVideo ? "play.rectangle.fill" : "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(highContrast ? .white : .indigo)
                    }
                }
            } else {
                Image(systemName: hasVideo ? "play.fill" : (linkedSceneTitle == nil ? "plus" : "arrow.right"))
                    .font(.title2.bold())
                    .foregroundStyle(markerForeground)
                    .frame(width: width ?? 48, height: height ?? 48)
                    .background(markerColor, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highContrast ? Color.white : Color.indigo, lineWidth: 3))
            }
        }
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isScanHighlighted ? (highContrast ? Color.black : Color.orange) : .clear,
                              lineWidth: 5)
                .allowsHitTesting(false))
            .accessibilityLabel(hasVideo ? "Play video for \(label)" :
                (linkedSceneTitle.map { "Open \($0) from \(label)" } ?? label))
            .accessibilityIdentifier("scene-hotspot-\(id)")
            .accessibilityHint(hasVideo ? "Play an attached video" :
                (linkedSceneTitle == nil ? behavior.title : "Open a related scene"))
            .accessibilityAction { action() }
    }

    @ViewBuilder var body: some View {
        if holdDuration > 0 {
            button.buttonStyle(HoldToActivateStyle(duration: holdDuration))
        } else {
            button.buttonStyle(.plain)
        }
    }
}
