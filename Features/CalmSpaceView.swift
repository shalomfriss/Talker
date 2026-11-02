import SwiftUI

private enum CalmScanTarget: Equatable {
    case openSpeak
    case speakRequest
    case need(String)
    case sensoryCanvas
    case ambientSounds
    case breathing
    case grounding
    case lowLight
    case back
}

private enum CalmTool: String, Identifiable {
    case sensoryCanvas, ambientSounds, breathing, grounding
    var id: String { rawValue }
}

struct CalmSpaceView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let onOpenSpeak: () -> Void
    @State private var selectedNeedID: String?
    @State private var showingLowLight = false
    @State private var selectedTool: CalmTool?
    @State private var isVisible = false
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private var language: String { store.settings.communicationLanguage }
    private var selectedNeed: CalmNeed? { CalmNeed.all.first { $0.id == selectedNeedID } }
    private var scanTargets: [CalmScanTarget] {
        var targets: [CalmScanTarget] = [.openSpeak]
        if selectedNeed != nil { targets.append(.speakRequest) }
        targets += CalmNeed.all.map { .need($0.id) }
        targets += [.sensoryCanvas, .ambientSounds, .breathing, .grounding, .lowLight, .back]
        return targets
    }
    private var highlightedScanTarget: CalmScanTarget? {
        guard store.settings.scanEnabled, isVisible, !showingLowLight, selectedTool == nil,
              !scanTargets.isEmpty else { return nil }
        return scanTargets[min(scanIndex, scanTargets.count - 1)]
    }
    private var currentScanCue: ScanCue? {
        guard let highlightedScanTarget else { return nil }
        return ScanCue(text: scanLabel(for: highlightedScanTarget), language: language)
    }
    private var scanTimerID: String {
        "\(store.settings.scanEnabled)-\(store.settings.scanMode.rawValue)-\(store.settings.scanInterval)-\(store.activeProfileID)"
    }
    private var scanHighlightColor: Color { store.settings.highContrast ? .black : .orange }

    var body: some View {
        VStack(spacing: 0) {
        if store.settings.scanEnabled { scanControlBar }
        ScrollViewReader { scrollProxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Choose what helps right now. You can stop or open the communication board at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Open communication board", systemImage: "quote.bubble.fill") { onOpenSpeak() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("calm-open-speak")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .openSpeak
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("calm-scan-open-speak")

                Text("Tell someone what you need")
                    .font(.title2.weight(.semibold))
                if let selectedNeed {
                    VStack(spacing: 16) {
                        Text(selectedNeed.text(language: language))
                            .font(.largeTitle.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 130)
                            .accessibilityIdentifier("calm-selected-message")
                        Button("Speak this request", systemImage: "speaker.wave.2.fill") {
                            store.speak(selectedNeed.text(language: language), language: language)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("calm-speak-request")
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(highlightedScanTarget == .speakRequest
                                ? scanHighlightColor : .clear, lineWidth: 4))
                        .id("calm-scan-speak-request")
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    ForEach(CalmNeed.all) { need in
                        Button {
                            selectNeed(need)
                        } label: {
                            VStack(spacing: 10) {
                                Text(need.symbol).font(.largeTitle).accessibilityHidden(true)
                                Text(need.text(language: language))
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(minHeight: 105)
                            .padding(10)
                            .background(selectedNeedID == need.id ? Color.indigo.opacity(0.2) : Color.indigo.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(highlightedScanTarget == .need(need.id)
                                    ? scanHighlightColor
                                    : (selectedNeedID == need.id ? Color.indigo : Color.clear),
                                    lineWidth: highlightedScanTarget == .need(need.id) ? 4 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedNeedID == need.id ? .isSelected : [])
                        .accessibilityIdentifier("calm-need-\(need.id)")
                        .id("calm-scan-need-\(need.id)")
                    }
                }

                Text("Optional focus tools")
                    .font(.title2.weight(.semibold))
                NavigationLink {
                    SensoryCanvasView()
                } label: {
                    Label("Sensory canvas", systemImage: "circle.hexagongrid")
                }
                .accessibilityIdentifier("calm-open-sensory-canvas")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlightedScanTarget == .sensoryCanvas
                        ? scanHighlightColor : .clear, lineWidth: 4))
                .id("calm-scan-sensory-canvas")
                NavigationLink {
                    SoundscapeView()
                } label: {
                    Label("Ambient sounds", systemImage: "waveform")
                }
                .accessibilityIdentifier("calm-open-ambient-sounds")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlightedScanTarget == .ambientSounds
                        ? scanHighlightColor : .clear, lineWidth: 4))
                .id("calm-scan-ambient-sounds")
                NavigationLink {
                    BreathingGuideView()
                } label: {
                    Label("Paced breathing", systemImage: "circle.dotted.circle")
                }
                .accessibilityIdentifier("calm-open-breathing")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlightedScanTarget == .breathing
                        ? scanHighlightColor : .clear, lineWidth: 4))
                .id("calm-scan-breathing")
                NavigationLink {
                    GroundingGuideView()
                } label: {
                    Label("Five senses grounding", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("calm-open-grounding")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlightedScanTarget == .grounding
                        ? scanHighlightColor : .clear, lineWidth: 4))
                .id("calm-scan-grounding")
                Button("Low-light screen", systemImage: "moon.fill") { showingLowLight = true }
                    .accessibilityIdentifier("calm-open-low-light")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .lowLight
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("calm-scan-low-light")
                Button("Back to routine", systemImage: "chevron.backward") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("calm-back")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .back
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("calm-scan-back")
            }
            .frame(maxWidth: 700)
            .padding(22)
            .frame(maxWidth: .infinity)
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
        .navigationTitle("Calm space")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedTool) { tool in
            switch tool {
            case .sensoryCanvas: SensoryCanvasView()
            case .ambientSounds: SoundscapeView()
            case .breathing: BreathingGuideView()
            case .grounding: GroundingGuideView()
            }
        }
        .fullScreenCover(isPresented: $showingLowLight) {
            LowLightView(need: selectedNeed, language: language)
                .environmentObject(store)
        }
        .onChange(of: store.activeProfileID) { _, _ in
            selectedNeedID = nil
            showingLowLight = false
            selectedTool = nil
            scanIndex = 0
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; store.stopScanCue() }
        .onChange(of: currentScanCue, initial: true) { _, cue in
            if let cue { store.previewScanCue(cue) }
            else { store.stopScanCue() }
        }
        .task(id: scanTimerID) { await runScanTimer() }
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.settings.scanMode == .step ? "STEP SCAN · CALM" : "AUTO SCAN · CALM")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No calm action")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("calm-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedTarget() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("calm-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") {
                        scanPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("calm-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("calm-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: CalmScanTarget) -> String {
        switch target {
        case .openSpeak: return "Open communication board"
        case .speakRequest: return "Speak this request"
        case .need(let id): return CalmNeed.all.first(where: { $0.id == id })?.text(language: language) ?? "Need"
        case .sensoryCanvas: return "Sensory canvas"
        case .ambientSounds: return "Ambient sounds"
        case .breathing: return "Paced breathing"
        case .grounding: return "Five senses grounding"
        case .lowLight: return "Low-light screen"
        case .back: return "Back to routine"
        }
    }

    private func scanScrollID(for target: CalmScanTarget) -> String? {
        switch target {
        case .openSpeak: return "calm-scan-open-speak"
        case .speakRequest: return "calm-scan-speak-request"
        case .need(let id): return "calm-scan-need-\(id)"
        case .sensoryCanvas: return "calm-scan-sensory-canvas"
        case .ambientSounds: return "calm-scan-ambient-sounds"
        case .breathing: return "calm-scan-breathing"
        case .grounding: return "calm-scan-grounding"
        case .lowLight: return "calm-scan-low-light"
        case .back: return "calm-scan-back"
        }
    }

    private func advanceScan() {
        guard !scanTargets.isEmpty else { scanIndex = 0; return }
        scanIndex = (scanIndex + 1) % scanTargets.count
    }

    private func selectNeed(_ need: CalmNeed) {
        selectedNeedID = need.id
        if store.settings.scanEnabled,
           let index = scanTargets.firstIndex(of: .speakRequest) { scanIndex = index }
    }

    private func selectHighlightedTarget() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35,
              let highlightedScanTarget else { return }
        lastScanActivation = now
        switch highlightedScanTarget {
        case .openSpeak: onOpenSpeak()
        case .speakRequest:
            if let selectedNeed { store.speak(selectedNeed.text(language: language), language: language) }
        case .need(let id):
            if let need = CalmNeed.all.first(where: { $0.id == id }) { selectNeed(need) }
        case .sensoryCanvas: selectedTool = .sensoryCanvas
        case .ambientSounds: selectedTool = .ambientSounds
        case .breathing: selectedTool = .breathing
        case .grounding: selectedTool = .grounding
        case .lowLight: showingLowLight = true
        case .back: dismiss()
        }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active && isVisible && !scanPaused && !showingLowLight && selectedTool == nil {
                advanceScan()
            }
        }
    }
}
