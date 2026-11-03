import PhotosUI
import SwiftUI

struct WeeklyActivityEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let activity: WeeklyActivity?
    let weekday: Int
    @State private var title: String
    @State private var pastingPhoto = false
    @State private var message: String
    @State private var symbol: String
    @State private var imageData: Data?
    @State private var audioData: Data?
    @State private var rewardChartID: UUID?
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
        _rewardChartID = State(initialValue: activity?.rewardChartID)
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
                    PictureLibraryPickerButton(title: "Picture library",
                                               identifier: "weekly-activity-picture-library") { picture in
                        imageData = picture.imageData
                    }
                    CameraPhotoButton { imageData = $0 }
                    PastePhotoButton(identifier: "weekly-activity-paste-photo", onPastingChange: { pastingPhoto = $0 }) { imageData = $0 }
                    if let imageData {
                        AsyncThumbnailImage(data: imageData, maxPixelSize: 400, contentMode: .fit) {
                            Color(uiColor: .secondarySystemBackground)
                        }
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
                Section("Reward chart") {
                    if store.rewardCharts.isEmpty {
                        Text("Create a reward chart from Routine → Rewards to link one here.")
                            .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            Button("No linked chart") { rewardChartID = nil }
                            ForEach(store.rewardCharts) { chart in
                                Button(chart.title) { rewardChartID = chart.id }
                            }
                        } label: {
                            HStack {
                                Text("Reward chart")
                                Spacer()
                                Text(store.rewardCharts.first(where: { $0.id == rewardChartID })?.title ?? "None")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("weekly-activity-reward-chart")
                        Text("Completing this activity adds one token per date while the chart has space. Unchecking it does not remove a token or award another one on the same date.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(activity == nil ? "New activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pastingPhoto)
                        .accessibilityIdentifier("save-weekly-activity")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                Task {
                    if let data = try? await photo?.loadTransferable(type: Data.self) {
                        imageData = await PhotoProcessing.preparedDataAsync(from: data)
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
                                     completedDates: activity?.completedDates,
                                     rewardChartID: rewardChartID,
                                     rewardedDates: rewardChartID == activity?.rewardChartID
                                     ? activity?.rewardedDates : nil)
        let saved = activity == nil
            ? store.addWeeklyActivity(updated, on: weekday)
            : store.updateWeeklyActivity(updated, on: weekday)
        if saved { dismiss() }
        else { errorMessage = "Give the activity a name and spoken message." }
    }
}
