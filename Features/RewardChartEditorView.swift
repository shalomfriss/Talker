import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RewardChartEditorView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    private let chartID: UUID?
    @State private var title: String
    @State private var pastingPhoto = false
    @State private var reward: String
    @State private var symbol: String
    @State private var targetTokens: Int
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImageImporter = false
    @State private var mediaError: String?

    init(chart: RewardChart?) {
        chartID = chart?.id
        _title = State(initialValue: chart?.title ?? "")
        _reward = State(initialValue: chart?.reward ?? "")
        _symbol = State(initialValue: chart?.symbol ?? "⭐️")
        _targetTokens = State(initialValue: chart?.targetTokens ?? 5)
        _photoData = State(initialValue: chart?.photoData)
    }

    private var canSave: Bool {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = reward.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 100 && !result.isEmpty && result.count <= 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chart") {
                    TextField("Chart name", text: $title)
                        .accessibilityIdentifier("reward-chart-name")
                    TextField("Reward to celebrate", text: $reward)
                        .accessibilityIdentifier("reward-chart-reward")
                    TextField("Token emoji", text: $symbol)
                        .accessibilityIdentifier("reward-chart-symbol")
                    Stepper("\(targetTokens) tokens to fill", value: $targetTokens, in: 1...20)
                        .accessibilityIdentifier("reward-chart-target")
                    Text("Choose a goal and reward that matter to you. This chart is optional and never changes the Speak board.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Reward photo") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose photo from Photos", systemImage: "photo")
                    }
                    PictureLibraryPickerButton(title: "Picture library",
                                               identifier: "reward-chart-picture-library") { picture in
                        photoData = picture.imageData
                    }
                    CameraPhotoButton { photoData = $0 }
                    PastePhotoButton(identifier: "reward-chart-paste-photo", onPastingChange: { pastingPhoto = $0 }) { photoData = $0 }
                    Button("Choose photo from Files", systemImage: "folder") {
                        showingImageImporter = true
                    }
                    if let photoData {
                        AsyncThumbnailImage(data: photoData, contentMode: .fit) {
                            Text("Loading photo…")
                                .foregroundStyle(.secondary)
                        }
                            .frame(maxHeight: 180)
                            .accessibilityLabel("Reward photo preview")
                        Button("Remove photo", role: .destructive) { self.photoData = nil }
                    }
                }
            }
            .navigationTitle(chartID == nil ? "New reward chart" : "Edit reward chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || pastingPhoto)
                        .accessibilityIdentifier("reward-chart-save")
                }
            }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self),
                              let prepared = await PhotoProcessing.preparedDataAsync(from: data) else {
                            mediaError = "Could not open that photo. Try Files or another photo."
                            return
                        }
                        photoData = prepared
                        mediaError = nil
                    } catch { mediaError = error.localizedDescription }
                }
            }
            .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    Task {
                        do {
                            guard let prepared = try await PhotoProcessing.preparedDataAsync(fromFile: url) else {
                                mediaError = "This file is not a usable image. Choose another photo."
                                return
                            }
                            photoData = prepared
                            mediaError = nil
                        } catch { mediaError = error.localizedDescription }
                    }
                case .failure(let error): mediaError = error.localizedDescription
                }
            }
            .alert("Photo error", isPresented: Binding(
                get: { mediaError != nil }, set: { if !$0 { mediaError = nil } }
            )) {
                Button("OK", role: .cancel) { mediaError = nil }
            } message: { Text(mediaError ?? "") }
        }
    }

    private func save() {
        if let chartID {
            guard let existing = store.rewardCharts.first(where: { $0.id == chartID }) else { return }
            let chart = RewardChart(id: chartID, title: title, reward: reward, symbol: symbol,
                                    targetTokens: targetTokens, earnedTokens: existing.earnedTokens,
                                    photoData: photoData)
            guard store.updateRewardChart(chart) else { return }
        } else {
            guard store.addRewardChart(title: title, reward: reward, symbol: symbol,
                                       targetTokens: targetTokens, photoData: photoData) != nil else { return }
        }
        dismiss()
    }
}
