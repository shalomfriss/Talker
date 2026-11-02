import SwiftUI

struct PracticeSetupView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let onStart: (PracticeActivity) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Pick a topic, then use the usual communication board together. Take turns when you want. You can skip any idea or stop at any time.")
                        .foregroundStyle(.secondary)
                }
                Section("Topics") {
                    ForEach(PracticeActivity.allCases) { activity in
                        Button {
                            onStart(activity)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(activity.title(language: store.settings.communicationLanguage))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(activity.detail(language: store.settings.communicationLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
                        }
                        .accessibilityIdentifier("practice-topic-\(activity.id)")
                    }
                }
            }
            .navigationTitle("Practice together")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            } }
        }
    }
}
