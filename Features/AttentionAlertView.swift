import SwiftUI
import UIKit

struct AttentionAlertView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAnnounced = false
    @State private var facingPartner = false
    @State private var isRepeating = false
    @State private var repeatTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .largeTitle) private var messageFontSize = 44

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bell.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(store.settings.highContrast ? .black : .indigo)
                    .accessibilityHidden(true)
                ScrollView {
                    Text(store.settings.attentionMessage)
                        .font(.system(size: messageFontSize, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(store.settings.highContrast ? .black : .indigo)
                        .rotationEffect(.degrees(facingPartner ? 180 : 0))
                        .accessibilityIdentifier("attention-message")
                }
                .frame(maxHeight: 360)
                Spacer()
                Button("Say again", systemImage: "speaker.wave.2.fill") { announce() }
                    .buttonStyle(.borderedProminent)
                    .tint(store.settings.highContrast ? .black : .indigo)
                    .controlSize(.large)
                    .accessibilityIdentifier("repeat-attention")
                    .disabled(isRepeating)
                Button(isRepeating ? "Stop repeating" : "Repeat until stopped",
                       systemImage: isRepeating ? "stop.fill" : "repeat") {
                    if isRepeating { stopRepeating() } else { startRepeating() }
                }
                .buttonStyle(.borderedProminent)
                .tint(isRepeating ? .red : (store.settings.highContrast ? .black : .indigo))
                .controlSize(.large)
                .accessibilityIdentifier("attention-auto-repeat")
                if isRepeating {
                    Text("The message repeats after each spoken announcement. It stops when you leave this screen.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                Button(facingPartner ? "Face me" : "Face partner", systemImage: "arrow.triangle.2.circlepath") {
                    facingPartner.toggle()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Rotate the message text for someone sitting opposite you")
                Button("Back to Speak") { dismiss() }
                    .buttonStyle(.bordered)
                    .padding(.bottom, 20)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(store.settings.highContrast ? Color.white : Color(red: 0.95, green: 0.96, blue: 1))
            .navigationTitle("Get attention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear {
                guard !hasAnnounced else { return }
                hasAnnounced = true
                announce()
            }
            .onDisappear { if isRepeating { stopRepeating() } }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active && isRepeating { stopRepeating() }
            }
        }
    }

    private func startRepeating() {
        guard !isRepeating else { return }
        isRepeating = true
        repeatTask = Task { @MainActor in
            while !Task.isCancelled {
                while store.isSpeechOutputActive {
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !Task.isCancelled else { return }
                guard !store.isSpeechOutputActive else { continue }
                announce()
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
        isRepeating = false
        store.stopSpeaking()
    }

    private func announce() {
        if store.settings.attentionHaptics {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        store.speak(store.settings.attentionMessage)
    }
}
