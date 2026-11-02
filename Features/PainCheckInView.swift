import SwiftUI
import UIKit

private enum PainScanTarget: Equatable {
    case speak, share, savePhrase
    case side(Bool)
    case location(PainLocation)
    case details
    case sensation(PainSensation)
    case scale(Int)
    case strength(Int)
    case saveCheckIn, history, back
}

struct PainCheckInView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var locations: Set<PainLocation> = []
    @State private var sensation: PainSensation?
    @State private var intensity = 0
    @State private var lastSavedMessage: String?
    @State private var showingBack = false
    @State private var showingDetails = false
    @State private var showingShare = false
    @State private var showingHistory = false
    @State private var isVisible = false
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private var language: String { store.settings.communicationLanguage }
    private var message: String {
        PainMessageComposer.message(locations: locations, sensation: sensation,
                                    intensity: intensity == 0 ? nil : intensity, language: language,
                                    maximumIntensity: store.settings.painScaleMaximum)
    }
    private var broadLocations: [PainLocation] {
        [.head, .neck, .leftArm, showingBack ? .upperBack : .chest,
         showingBack ? .lowerBack : .stomach, .rightArm, .leftLeg, .rightLeg]
    }
    private var detailLocations: [PainLocation] {
        PainLocation.allCases.filter { $0.broadArea != nil }
    }
    private var canSaveCheckIn: Bool {
        store.settings.saveFeelingsLog && lastSavedMessage != message
    }
    private var scanTargets: [PainScanTarget] {
        var targets: [PainScanTarget] = [.speak, .share, .savePhrase, .side(false), .side(true)]
        targets += broadLocations.map { .location($0) }
        targets.append(.details)
        if showingDetails { targets += detailLocations.map { .location($0) } }
        targets += PainSensation.allCases.map { .sensation($0) }
        targets += [.scale(5), .scale(10)]
        targets += (1...store.settings.painScaleMaximum).map { .strength($0) }
        if canSaveCheckIn { targets.append(.saveCheckIn) }
        if !store.feelingsLog.isEmpty { targets.append(.history) }
        targets.append(.back)
        return targets
    }
    private var highlightedScanTarget: PainScanTarget? {
        guard store.settings.scanEnabled, isVisible, !showingShare, !showingHistory,
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
    private var scanHighlightedLocation: PainLocation? {
        if case .location(let location) = highlightedScanTarget { return location }
        return nil
    }
    private var scanHighlightedSide: Bool? {
        if case .side(let back) = highlightedScanTarget { return back }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
        if store.settings.scanEnabled { scanControlBar }
        ScrollViewReader { scrollProxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("I am in pain")
                    .font(.title2.weight(.bold))
                Text("You can speak now, or add details below.")
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.title3.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("pain-message")
                HStack {
                    Button("Speak pain", systemImage: "speaker.wave.2.fill") {
                        store.speak(message)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("pain-speak")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .speak
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-speak")
                    ShareLink(item: message) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("pain-share")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .share
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-share")
                }
                Button("Save phrase", systemImage: "star") { store.addPhrase(message) }
                    .buttonStyle(.bordered)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .savePhrase
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-save-phrase")

                PainBodyMapView(selectedLocations: $locations,
                                showingBack: $showingBack, showingDetails: $showingDetails,
                                language: language, highlightedLocation: scanHighlightedLocation,
                                highlightedSide: scanHighlightedSide,
                                detailsHighlighted: highlightedScanTarget == .details,
                                highContrast: store.settings.highContrast)

                VStack(alignment: .leading, spacing: 12) {
                    Text("What does it feel like? (optional)")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 9)], spacing: 9) {
                        ForEach(PainSensation.allCases) { option in
                            Button {
                                sensation = sensation == option ? nil : option
                            } label: {
                                Label(option.label(language: language),
                                      systemImage: sensation == option ? "checkmark.circle.fill" : "circle")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(.indigo)
                            .accessibilityLabel(option.label(language: language))
                            .accessibilityAddTraits(sensation == option ? .isSelected : [])
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(highlightedScanTarget == .sensation(option)
                                    ? scanHighlightColor : .clear, lineWidth: 4))
                            .id("pain-scan-sensation-\(option.rawValue)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("How strong is it? (optional)")
                        .font(.headline)
                    Picker("Pain scale", selection: Binding(
                        get: { store.settings.painScaleMaximum },
                        set: { maximum in
                            store.settings.painScaleMaximum = maximum
                            intensity = 0
                        }
                    )) {
                        Text("1–5").tag(5)
                        Text("1–10").tag(10)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("pain-scale-range")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .scale(5) ||
                                      highlightedScanTarget == .scale(10)
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-scale")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                              spacing: 8) {
                        ForEach(1...store.settings.painScaleMaximum, id: \.self) { level in
                            Button("\(level)") { intensity = intensity == level ? 0 : level }
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(intensity == level ? Color.indigo.opacity(0.22) : Color.white,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(highlightedScanTarget == .strength(level)
                                        ? scanHighlightColor
                                        : (intensity == level ? Color.indigo : Color.gray.opacity(0.35)),
                                        lineWidth: highlightedScanTarget == .strength(level) ? 4 : 1))
                                .accessibilityLabel("Pain strength \(level) out of \(store.settings.painScaleMaximum)")
                                .accessibilityAddTraits(intensity == level ? .isSelected : [])
                                .accessibilityIdentifier("pain-strength-\(level)")
                                .id("pain-scan-strength-\(level)")
                        }
                    }
                }

                Button("Save pain check-in", systemImage: "square.and.arrow.down") {
                    saveCheckIn()
                }
                .buttonStyle(.bordered)
                .disabled(!canSaveCheckIn)
                .accessibilityIdentifier("save-pain-entry")
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlightedScanTarget == .saveCheckIn
                        ? scanHighlightColor : .clear, lineWidth: 4))
                .id("pain-scan-save-check-in")
                if !store.settings.saveFeelingsLog {
                    Text("Turn on the private feelings log in Settings to save a pain check-in. Speaking and sharing do not save it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if lastSavedMessage == message {
                    Label("Saved to your private feelings log", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                if !store.feelingsLog.isEmpty {
                    NavigationLink {
                        FeelingsHistoryView()
                    } label: {
                        Label("Review saved check-ins", systemImage: "clock.arrow.circlepath")
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .history
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-history")
                }
                Button("Back", systemImage: "chevron.backward") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pain-back")
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(highlightedScanTarget == .back
                            ? scanHighlightColor : .clear, lineWidth: 4))
                    .id("pain-scan-back")
            }
            .padding()
            .frame(maxWidth: 600)
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
        .navigationTitle("Pain check-in")
        .navigationDestination(isPresented: $showingHistory) { FeelingsHistoryView() }
        .sheet(isPresented: $showingShare) { PainTextShareSheet(text: message) }
        .onChange(of: store.activeProfileID) { _, _ in
            locations = []
            sensation = nil
            intensity = 0
            lastSavedMessage = nil
            showingBack = false
            showingDetails = false
            showingShare = false
            showingHistory = false
            scanIndex = 0
        }
        .onChange(of: language) { _, _ in lastSavedMessage = nil }
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
            Text(store.settings.scanMode == .step ? "STEP SCAN · PAIN" : "AUTO SCAN · PAIN")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No pain action")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pain-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedTarget() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("pain-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") {
                        scanPaused.toggle()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("pain-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("pain-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: PainScanTarget) -> String {
        switch target {
        case .speak: return "Speak pain"
        case .share: return "Share"
        case .savePhrase: return "Save phrase"
        case .side(let back): return back ? "Back" : "Front"
        case .location(let location): return location.label(language: language)
        case .details: return language == "es" ? "Elegir una zona más específica" : "Choose a more specific spot"
        case .sensation(let option): return option.label(language: language)
        case .scale(let maximum): return "1–\(maximum)"
        case .strength(let level): return "Pain strength \(level) out of \(store.settings.painScaleMaximum)"
        case .saveCheckIn: return "Save pain check-in"
        case .history: return "Review saved check-ins"
        case .back: return "Back"
        }
    }

    private func scanScrollID(for target: PainScanTarget) -> String? {
        switch target {
        case .speak: return "pain-scan-speak"
        case .share: return "pain-scan-share"
        case .savePhrase: return "pain-scan-save-phrase"
        case .side: return "pain-scan-side"
        case .location(let location): return "pain-scan-location-\(location.rawValue)"
        case .details: return "pain-scan-details"
        case .sensation(let option): return "pain-scan-sensation-\(option.rawValue)"
        case .scale: return "pain-scan-scale"
        case .strength(let level): return "pain-scan-strength-\(level)"
        case .saveCheckIn: return "pain-scan-save-check-in"
        case .history: return "pain-scan-history"
        case .back: return "pain-scan-back"
        }
    }

    private func advanceScan() {
        guard !scanTargets.isEmpty else { scanIndex = 0; return }
        scanIndex = (scanIndex + 1) % scanTargets.count
    }

    private func selectHighlightedTarget() {
        let now = Date()
        guard now.timeIntervalSince(lastScanActivation) >= 0.35,
              let highlightedScanTarget else { return }
        lastScanActivation = now
        switch highlightedScanTarget {
        case .speak: store.speak(message)
        case .share: showingShare = true
        case .savePhrase: store.addPhrase(message)
        case .side(let back): showingBack = back
        case .location(let location): locations = PainLocation.toggled(location, in: locations)
        case .details: showingDetails.toggle()
        case .sensation(let option): sensation = sensation == option ? nil : option
        case .scale(let maximum):
            store.settings.painScaleMaximum = maximum
            intensity = 0
        case .strength(let level): intensity = intensity == level ? 0 : level
        case .saveCheckIn: saveCheckIn()
        case .history: showingHistory = true
        case .back: dismiss()
        }
    }

    private func saveCheckIn() {
        guard canSaveCheckIn, store.savePainEntry(message: message, intensity: intensity) else { return }
        lastSavedMessage = message
        if store.settings.scanEnabled,
           let index = scanTargets.firstIndex(of: .history) ?? scanTargets.firstIndex(of: .back) {
            scanIndex = index
        }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active && isVisible && !scanPaused && !showingShare && !showingHistory {
                advanceScan()
            }
        }
    }
}

private struct PainTextShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
