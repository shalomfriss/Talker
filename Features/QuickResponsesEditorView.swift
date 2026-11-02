import SwiftUI

struct QuickResponsesEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    @State private var responses: [QuickResponse]
    @State private var recordingResponse: QuickResponse?
    @State private var freshlyRecordedText: [UUID: String] = [:]

    init(responses: [QuickResponse]) {
        _responses = State(initialValue: responses)
    }

    var body: some View {
        Form {
            Section {
                Text("These replies stay available on the main tabs and typing screen. Choose Add and speak or Speak only for each reply. Speak only leaves your current message as it is. Leave the Spanish line blank to use English in both languages. You can record a voice for each reply.")
                    .foregroundStyle(.secondary)
            }
            Section("Replies (\(responses.count) of \(QuickResponse.maximumCount))") {
                ForEach($responses) { $response in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("English reply", text: $response.text, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityIdentifier("quick-reply-english-\(response.id)")
                        TextField("Spanish reply (optional)", text: $response.spanishText, axis: .vertical)
                            .lineLimit(1...3)
                            .accessibilityIdentifier("quick-reply-spanish-\(response.id)")
                        Picker("When tapped", selection: $response.action) {
                            ForEach(QuickResponseAction.allCases) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("quick-reply-action-\(response.id)")
                        Button(response.audioData == nil ? "Record a voice" : "Edit recorded voice",
                               systemImage: response.audioData == nil ? "mic" : "waveform") {
                            recordingResponse = response
                        }
                        .disabled(response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("quick-reply-voice-\(response.id)")
                    }
                }
                .onDelete { responses.remove(atOffsets: $0) }
                .onMove { responses.move(fromOffsets: $0, toOffset: $1) }
                Button("Add quick reply", systemImage: "plus") {
                    responses.append(QuickResponse(text: ""))
                }
                .disabled(responses.count >= QuickResponse.maximumCount)
                .accessibilityIdentifier("add-quick-reply")
            }
            Section {
                Button("Use starter replies", systemImage: "arrow.counterclockwise") {
                    responses = QuickResponse.starterReplies
                }
                Text("Use Edit to reorder or remove replies. Leave this list empty to hide the reply bar. Each phrase can be up to \(QuickResponse.maximumTextLength) characters; duplicates are not saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Quick replies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let updated = responses.map { response in
                        var result = response
                        let recordedText = freshlyRecordedText[response.id]
                            ?? store.settings.quickResponses.first(where: { $0.id == response.id })?.text
                        if result.audioData != nil, let recordedText, recordedText != response.text {
                            result.audioData = nil
                        }
                        return result
                    }
                    store.settings.quickResponses = QuickResponse.cleaned(updated)
                    dismiss()
                }
                .disabled(!QuickResponse.canSave(responses))
                .accessibilityIdentifier("save-quick-replies")
            }
        }
        .sheet(item: $recordingResponse) { response in
            QuickResponseRecordingEditorView(response: response) { audioData in
                guard let index = responses.firstIndex(where: { $0.id == response.id }) else { return }
                responses[index].audioData = audioData
                if audioData != nil { freshlyRecordedText[response.id] = response.text }
                else { freshlyRecordedText.removeValue(forKey: response.id) }
            }
        }
    }
}
