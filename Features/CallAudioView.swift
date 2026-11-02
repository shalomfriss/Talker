import Accessibility
import AVFoundation
import SwiftUI

struct CallAudioView: View {
    @EnvironmentObject private var callAudio: CallAudioManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorText = ""
    var isModal = false

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Call", value: callAudio.isCallAvailable ? "Active and supported" : "No supported call active")
                LabeledContent("Open Voice audio", value: callAudio.isEnabled ? "Added to calls" : "Local only")
                Text(callAudio.isCallAvailable && callAudio.isEnabled
                     ? "Speak a message in Open Voice. You and the person on the call should hear it."
                     : "Start a Phone, FaceTime, or supported VoIP call, then return to Open Voice to speak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Add audio to calls") {
                switch callAudio.permission {
                case .granted:
                    Button(callAudio.isEnabled ? "Stop adding Open Voice audio" : "Add Open Voice audio to calls",
                           systemImage: callAudio.isEnabled ? "phone.down" : "phone.arrow.up.right") {
                        Task { await callAudio.setEnabled(!callAudio.isEnabled) }
                    }
                    .disabled(callAudio.isWorking)
                    .accessibilityIdentifier("call-audio-toggle")
                case .undetermined:
                    Button("Allow and add Open Voice audio", systemImage: "phone.arrow.up.right") {
                        Task { await callAudio.setEnabled(true) }
                    }
                    .disabled(callAudio.isWorking)
                    .accessibilityIdentifier("call-audio-request")
                case .serviceDisabled:
                    Text("The device’s Add Audio in Calls service is off.")
                    openSystemSettingsButton
                case .denied:
                    Text("Open Voice does not have permission to add audio to calls.")
                    openSystemSettingsButton
                @unknown default:
                    Text("Call audio permission is unavailable right now.")
                }
                Text("This setting is controlled by the device. Muting your microphone also mutes added audio. Turn the feature off here when you want Open Voice sound to stay local.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Call audio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { callAudio.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.microphoneInjectionCapabilitiesChangeNotification)) { _ in
            callAudio.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { callAudio.refresh() }
        }
        .onChange(of: callAudio.errorMessage) { _, error in
            if let error { show(error) }
        }
        .alert("Call audio", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorText) }
    }

    private var openSystemSettingsButton: some View {
        Button("Open Add Audio in Calls settings", systemImage: "gear") {
            Task {
                do { try await AccessibilitySettings.openSettings(for: .allowAppsToAddAudioToCalls) }
                catch { show(error.localizedDescription) }
            }
        }
        .accessibilityIdentifier("call-audio-system-settings")
    }

    private func show(_ error: String) {
        errorText = error
        showingError = true
    }
}
