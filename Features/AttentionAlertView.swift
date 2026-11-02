import SwiftUI
import UIKit

struct AttentionAlertView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var hasAnnounced = false
    @State private var facingPartner = false
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
        }
    }

    private func announce() {
        if store.settings.attentionHaptics {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        store.speak(store.settings.attentionMessage)
    }
}
