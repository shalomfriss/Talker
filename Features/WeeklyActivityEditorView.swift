import PhotosUI
import SwiftUI

struct WeeklyActivityEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let activity: WeeklyActivity?
    let weekday: Int
    @State private var title: String
    @State private var message: String
    @State private var symbol: String
    @State private var imageData: Data?
    @State private var audioData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    init(activity: WeeklyActivity?, weekday: Int) {
        self.activity = activity
        self.weekday = weekday
        _title = State(initialValue: activity?.option.label ?? "")
        _message = State(initialValue: activity?.option.message ?? "")
        _symbol = State(initialValue: activity?.option.symbol ?? "⭐️")
        _imageData = State(initialValue: activity?.option.imageData)
        _audioData = State(initialValue: activity?.option.audioData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("What will happen?", text: $title)
                        .accessibilityIdentifier("weekly-activity-title")
                    TextField("What should it say?", text: $message)
                        .accessibilityIdentifier("weekly-activity-message")
                    TextField("Emoji or symbol", text: $symbol)
                }
                Section("Picture") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose or change photo", systemImage: "photo")
                    }
                    CameraPhotoButton { imageData = $0 }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                        Button("Remove photo", role: .destructive) { self.imageData = nil }
                    }
                    Text("A photo is optional. You can also add a button with a recorded voice from Speak.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let audioData {
                    Section("Recorded voice") {
                        Button("Play recording", systemImage: "play.fill") {
                            store.playRecorded(audioData)
                        }
                        Button("Remove recording", role: .destructive) { self.audioData = nil }
                    }
                }
            }
            .navigationTitle(activity == nil ? "New activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-weekly-activity")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = PhotoProcessing.preparedData(from: data)
                    }
                }
            }
            .alert("Could not save activity", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Check the activity name.")
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let option = ChoiceOption(label: cleanTitle, symbol: symbol.isEmpty ? "⭐️" : symbol,
                                  message: cleanMessage.isEmpty ? cleanTitle : cleanMessage,
                                  imageData: imageData, audioData: audioData)
        let updated = WeeklyActivity(id: activity?.id ?? UUID(), option: option,
                                     completedOn: activity?.completedOn,
                                     completedDates: activity?.completedDates)
        let saved = activity == nil
            ? store.addWeeklyActivity(updated, on: weekday)
            : store.updateWeeklyActivity(updated, on: weekday)
        if saved { dismiss() }
        else { errorMessage = "Give the activity a name and spoken message." }
    }
}
