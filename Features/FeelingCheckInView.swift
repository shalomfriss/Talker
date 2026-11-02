import SwiftUI
import UIKit

private enum FeelingScanTarget: Equatable {
    case pain
    case feeling(UUID)
    case intensity(Int)
    case support(Int)
    case speak, share, savePhrase, saveCheckIn, history, back
}

struct FeelingCheckInView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var feeling: CommunicationItem?
    @State private var intensity = 3
    @State private var support: String?
    @State private var lastSavedMessage: String?
    @State private var showingPain = false
    @State private var showingShare = false
    @State private var showingHistory = false
    @State private var isVisible = false
    @State private var scanIndex = 0
    @State private var scanPaused = false
    @State private var lastScanActivation = Date.distantPast

    private let supportOptions: [(english: String, spanish: String)] = [
        ("Please give me space.", "Por favor, dame espacio."),
        ("I need a quiet place.", "Necesito un lugar tranquilo."),
        ("Please stay with me.", "Por favor, quédate conmigo."),
        ("I need help.", "Necesito ayuda."),
        ("Please give me time to answer.", "Por favor, dame tiempo para responder.")
    ]

    private var displayedSupport: String? {
        guard let support else { return nil }
        guard store.settings.communicationLanguage == "es" else { return support }
        return supportOptions.first(where: { $0.english == support })?.spanish ?? support
    }

    private var message: String {
        guard let feeling else { return "" }
        return FeelingMessageComposer.message(
            englishFeeling: feeling.label, displayedFeeling: store.displayLabel(for: feeling),
            language: store.settings.communicationLanguage, intensity: intensity,
            support: displayedSupport)
    }

    private var feelings: [CommunicationItem] { store.items.filter { $0.category == "Feelings" } }
    private var canSaveCheckIn: Bool {
        store.settings.saveFeelingsLog && lastSavedMessage != message
    }
    private var scanTargets: [FeelingScanTarget] {
        var targets: [FeelingScanTarget] = [.pain]
        targets += feelings.map { .feeling($0.id) }
        targets += (1...5).map { .intensity($0) }
        targets += supportOptions.indices.map { .support($0) }
        if !message.isEmpty {
            targets += [.speak, .share, .savePhrase]
            if canSaveCheckIn { targets.append(.saveCheckIn) }
        }
        if !store.feelingsLog.isEmpty { targets.append(.history) }
        targets.append(.back)
        return targets
    }
    private var highlightedScanTarget: FeelingScanTarget? {
        guard store.settings.scanEnabled, isVisible, !showingPain, !showingShare, !showingHistory,
              !scanTargets.isEmpty else { return nil }
        return scanTargets[min(scanIndex, scanTargets.count - 1)]
    }
    private var currentScanCue: ScanCue? {
        guard let highlightedScanTarget else { return nil }
        return ScanCue(text: scanLabel(for: highlightedScanTarget),
                       language: store.settings.communicationLanguage)
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
            VStack(alignment: .leading, spacing: 22) {
                Button { showingPain = true } label: {
                    Label("Tell someone about pain", systemImage: "cross.case")
                }
                .accessibilityIdentifier("feeling-open-pain")
                .overlay(scanOutline(for: .pain))
                .id("feeling-scan-pain")
                Text("Choose a feeling")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 10)], spacing: 10) {
                    ForEach(feelings) { item in
                        Button {
                            selectFeeling(item)
                        } label: {
                            VStack(spacing: 6) {
                                Text(item.symbol).font(.largeTitle).accessibilityHidden(true)
                                Text(store.displayLabel(for: item)).font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 82)
                            .background(feeling?.id == item.id ? Color.indigo.opacity(0.22) : Color.indigo.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(highlightedScanTarget == .feeling(item.id)
                                    ? scanHighlightColor : (feeling?.id == item.id ? Color.indigo : .clear),
                                    lineWidth: highlightedScanTarget == .feeling(item.id) ? 4 : 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(store.displayLabel(for: item))
                        .accessibilityAddTraits(feeling?.id == item.id ? .isSelected : [])
                        .accessibilityIdentifier("feeling-option-\(item.id)")
                        .id("feeling-scan-option-\(item.id)")
                    }
                }

                Text("How strong is it?")
                    .font(.headline)
                if store.settings.scanEnabled {
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { level in
                            Button("\(level)") { selectIntensity(level) }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Strength \(level) out of 5")
                                .accessibilityAddTraits(intensity == level ? .isSelected : [])
                                .accessibilityIdentifier("feeling-intensity-\(level)")
                                .overlay(scanOutline(for: .intensity(level)))
                                .id("feeling-scan-intensity-\(level)")
                        }
                    }
                } else {
                    Picker("Feeling strength", selection: $intensity) {
                        ForEach(1...5, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityValue("\(intensity) out of 5")
                }

                Text("What would help? (optional)")
                    .font(.headline)
                VStack(spacing: 8) {
                    ForEach(supportOptions.indices, id: \.self) { index in
                        let option = supportOptions[index]
                        Button {
                            selectSupport(index)
                        } label: {
                            HStack {
                                Text(store.settings.communicationLanguage == "es" ? option.spanish : option.english)
                                Spacer()
                                if support == option.english { Image(systemName: "checkmark.circle.fill") }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityAddTraits(support == option.english ? .isSelected : [])
                        .accessibilityIdentifier("feeling-support-\(index)")
                        .overlay(scanOutline(for: .support(index)))
                        .id("feeling-scan-support-\(index)")
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    HStack {
                        Button("Speak", systemImage: "speaker.wave.2.fill") { store.speak(message) }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("feeling-speak")
                            .overlay(scanOutline(for: .speak))
                            .id("feeling-scan-speak")
                        Button("Share", systemImage: "square.and.arrow.up") { showingShare = true }
                            .accessibilityIdentifier("feeling-share")
                            .overlay(scanOutline(for: .share))
                            .id("feeling-scan-share")
                        Button("Save phrase", systemImage: "star") { store.addPhrase(message) }
                            .accessibilityIdentifier("feeling-save-phrase")
                            .overlay(scanOutline(for: .savePhrase))
                            .id("feeling-scan-save-phrase")
                    }
                    Button("Save check-in", systemImage: "square.and.arrow.down") { saveCheckIn() }
                        .buttonStyle(.bordered)
                        .disabled(!canSaveCheckIn)
                        .accessibilityIdentifier("save-feeling-entry")
                        .overlay(scanOutline(for: .saveCheckIn))
                        .id("feeling-scan-save-check-in")
                    if !store.settings.saveFeelingsLog {
                        Text("Turn on the private feelings log in Settings to save a check-in. Speaking and sharing do not save it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if lastSavedMessage == message {
                        Label("Saved to your private feelings log", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                if !store.feelingsLog.isEmpty {
                    Button { showingHistory = true } label: {
                        Label("Review saved check-ins", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("feeling-history")
                    .overlay(scanOutline(for: .history))
                    .id("feeling-scan-history")
                }
                Button("Back", systemImage: "chevron.backward") { dismiss() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("feeling-back")
                    .overlay(scanOutline(for: .back))
                    .id("feeling-scan-back")
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: highlightedScanTarget) { _, target in
            if let target {
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(scanScrollID(for: target), anchor: .center)
                }
            }
        }
        }
        }
        .navigationTitle("How I feel")
        .navigationDestination(isPresented: $showingPain) { PainCheckInView() }
        .navigationDestination(isPresented: $showingHistory) { FeelingsHistoryView() }
        .sheet(isPresented: $showingShare) { FeelingTextShareSheet(text: message) }
        .onChange(of: store.activeProfileID) { _, _ in
            feeling = nil
            support = nil
            intensity = 3
            lastSavedMessage = nil
            showingPain = false
            showingShare = false
            showingHistory = false
            scanIndex = 0
        }
        .onChange(of: store.settings.communicationLanguage) { _, _ in lastSavedMessage = nil }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; store.stopScanCue() }
        .onChange(of: currentScanCue, initial: true) { _, cue in
            if let cue { store.previewScanCue(cue) }
            else { store.stopScanCue() }
        }
        .task(id: scanTimerID) { await runScanTimer() }
    }

    private func saveCheckIn() {
        guard let feeling else { return }
        if store.saveFeelingEntry(label: store.displayLabel(for: feeling), symbol: feeling.symbol,
                                  intensity: intensity, support: displayedSupport, message: message) {
            lastSavedMessage = message
        }
    }

    private func scanOutline(for target: FeelingScanTarget) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(highlightedScanTarget == target ? scanHighlightColor : .clear,
                          lineWidth: 4)
            .allowsHitTesting(false)
    }

    private var scanControlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.settings.scanMode == .step ? "STEP SCAN · FEELINGS" : "AUTO SCAN · FEELINGS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(highlightedScanTarget.map(scanLabel(for:)) ?? "No feelings action")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("feeling-scan-target")
            HStack(spacing: 8) {
                Button("Select", systemImage: "checkmark.circle.fill") { selectHighlightedTarget() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(" ", modifiers: [])
                    .accessibilityIdentifier("feeling-scan-select")
                if store.settings.scanMode == .automatic {
                    Button(scanPaused ? "Resume" : "Pause",
                           systemImage: scanPaused ? "play.fill" : "pause.fill") { scanPaused.toggle() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("feeling-scan-pause")
                }
                Button("Next", systemImage: "arrow.right") { advanceScan() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("n", modifiers: [])
                    .accessibilityIdentifier("feeling-scan-next")
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(store.settings.highContrast ? Color.white : Color.yellow.opacity(0.2))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func scanLabel(for target: FeelingScanTarget) -> String {
        switch target {
        case .pain: return "Tell someone about pain"
        case .feeling(let id):
            guard let item = feelings.first(where: { $0.id == id }) else { return "Feeling" }
            return store.displayLabel(for: item)
        case .intensity(let level):
            return store.settings.communicationLanguage == "es"
                ? "Intensidad \(level) de 5" : "Strength \(level) out of 5"
        case .support(let index):
            guard supportOptions.indices.contains(index) else { return "Support" }
            let option = supportOptions[index]
            return store.settings.communicationLanguage == "es" ? option.spanish : option.english
        case .speak: return "Speak"
        case .share: return "Share"
        case .savePhrase: return "Save phrase"
        case .saveCheckIn: return "Save check-in"
        case .history: return "Review saved check-ins"
        case .back: return "Back"
        }
    }

    private func scanScrollID(for target: FeelingScanTarget) -> String {
        switch target {
        case .pain: return "feeling-scan-pain"
        case .feeling(let id): return "feeling-scan-option-\(id)"
        case .intensity(let level): return "feeling-scan-intensity-\(level)"
        case .support(let index): return "feeling-scan-support-\(index)"
        case .speak: return "feeling-scan-speak"
        case .share: return "feeling-scan-share"
        case .savePhrase: return "feeling-scan-save-phrase"
        case .saveCheckIn: return "feeling-scan-save-check-in"
        case .history: return "feeling-scan-history"
        case .back: return "feeling-scan-back"
        }
    }

    private func focusScan(on target: FeelingScanTarget) {
        if let index = scanTargets.firstIndex(of: target) { scanIndex = index }
    }

    private func selectFeeling(_ item: CommunicationItem) {
        feeling = item
        if store.settings.scanEnabled { focusScan(on: .intensity(intensity)) }
    }

    private func selectIntensity(_ level: Int) {
        intensity = level
        if store.settings.scanEnabled { focusScan(on: .support(0)) }
    }

    private func selectSupport(_ index: Int) {
        guard supportOptions.indices.contains(index) else { return }
        let option = supportOptions[index]
        support = support == option.english ? nil : option.english
        if store.settings.scanEnabled, !message.isEmpty { focusScan(on: .speak) }
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
        case .pain: showingPain = true
        case .feeling(let id):
            if let item = feelings.first(where: { $0.id == id }) { selectFeeling(item) }
        case .intensity(let level): selectIntensity(level)
        case .support(let index): selectSupport(index)
        case .speak: store.speak(message)
        case .share: showingShare = true
        case .savePhrase: store.addPhrase(message)
        case .saveCheckIn: saveCheckIn()
        case .history: showingHistory = true
        case .back: dismiss()
        }
    }

    @MainActor
    private func runScanTimer() async {
        guard store.settings.scanEnabled, store.settings.scanMode == .automatic else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.settings.scanInterval))
            guard !Task.isCancelled else { return }
            if scenePhase == .active, isVisible, !scanPaused,
               !showingPain, !showingShare, !showingHistory {
                advanceScan()
            }
        }
    }
}

private struct FeelingTextShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
