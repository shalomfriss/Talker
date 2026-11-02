import SwiftUI

struct RewardChartDetailView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.dismiss) private var dismiss
    let chartID: UUID
    @State private var showingEditor = false
    @State private var showingReset = false
    @State private var showingDelete = false
    @State private var showingCollected = false

    private var chart: RewardChart? {
        store.rewardCharts.first { $0.id == chartID }
    }

    var body: some View {
        Group {
            if let chart {
                ScrollView {
                    VStack(spacing: 20) {
                        rewardPicture(chart)
                        Text(chart.title)
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Reward: \(chart.reward)")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                        Text(chart.isComplete ? "Goal reached!" : "\(chart.earnedTokens) of \(chart.targetTokens) tokens")
                            .font(.headline.monospacedDigit())
                            .accessibilityIdentifier("reward-progress")
                        ProgressView(value: Double(chart.earnedTokens), total: Double(chart.targetTokens))
                            .tint(.orange)
                            .accessibilityLabel("Reward chart progress")
                        tokenGrid(chart)
                        HStack(spacing: 12) {
                            Button("Undo token", systemImage: "minus.circle") {
                                _ = store.setRewardChartTokens(id: chartID, count: chart.earnedTokens - 1)
                            }
                            .disabled(chart.earnedTokens == 0)
                            .accessibilityIdentifier("reward-undo-token")
                            Button("Add token", systemImage: "plus.circle.fill") {
                                _ = store.setRewardChartTokens(id: chartID, count: chart.earnedTokens + 1)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(chart.isComplete)
                            .accessibilityIdentifier("reward-add-token")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        if chart.isComplete {
                            Button("Mark reward collected", systemImage: "gift.fill") {
                                showingCollected = store.collectReward(id: chartID) != nil
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("reward-collect")
                        }
                        Button("Start chart again", systemImage: "arrow.counterclockwise") {
                            showingReset = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(chart.earnedTokens == 0)
                        .accessibilityIdentifier("reward-reset")
                        .confirmationDialog("Start this chart again?", isPresented: $showingReset) {
                            Button("Start again") { _ = store.startRewardChartAgain(id: chartID) }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This clears the current tokens. Collected rewards stay in the collection.")
                        }
                    }
                    .frame(maxWidth: 600)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("Chart not found", systemImage: "star.circle")
            }
        }
        .navigationTitle("Reward chart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if chart != nil {
                Button("Edit chart", systemImage: "pencil") { showingEditor = true }
                    .accessibilityIdentifier("reward-edit")
                Menu("More chart options", systemImage: "ellipsis.circle") {
                    Button("Delete chart", systemImage: "trash", role: .destructive) {
                        showingDelete = true
                    }
                }
                .confirmationDialog("Delete this reward chart?", isPresented: $showingDelete) {
                    Button("Delete chart", role: .destructive) {
                        if store.deleteRewardChart(id: chartID) { dismiss() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Collected reward records stay in the collection.")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let chart { RewardChartEditorView(chart: chart) }
        }
        .alert("Reward collected", isPresented: $showingCollected) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your chart is ready to use again. This reward was saved in Collected rewards.")
        }
    }

    private func tokenGrid(_ chart: RewardChart) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
            ForEach(0..<chart.targetTokens, id: \.self) { index in
                let earned = index < chart.earnedTokens
                Button {
                    _ = store.setRewardChartTokens(id: chartID, count: earned ? index : index + 1)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text(chart.symbol)
                            .font(.title)
                            .opacity(earned ? 1 : 0.25)
                            .frame(maxWidth: .infinity, minHeight: 64)
                        Image(systemName: earned ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .padding(4)
                    }
                    .background(earned ? Color.orange.opacity(0.2) : Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Token \(index + 1), \(earned ? "earned" : "empty")")
                .accessibilityHint(earned ? "Tap to keep \(index) tokens" : "Tap to fill through token \(index + 1)")
                .accessibilityIdentifier("reward-token-\(index + 1)")
            }
        }
    }

    @ViewBuilder
    private func rewardPicture(_ chart: RewardChart) -> some View {
        if let data = chart.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Reward photo")
        } else {
            Text(chart.symbol)
                .font(.system(size: 72))
                .accessibilityHidden(true)
        }
    }
}
