import SwiftUI

struct RewardChartsView: View {
    @EnvironmentObject private var store: CommunicationStore
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                Text("Use these optional charts to celebrate progress. Tokens and rewards never limit access to communication.")
                    .foregroundStyle(.secondary)
            }
            Section("My charts") {
                if store.rewardCharts.isEmpty {
                    ContentUnavailableView("No reward charts yet", systemImage: "star.circle",
                                           description: Text("Make a chart for a goal you choose."))
                }
                ForEach(store.rewardCharts) { chart in
                    NavigationLink {
                        RewardChartDetailView(chartID: chart.id)
                    } label: {
                        HStack(spacing: 12) {
                            rewardPicture(chart)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(chart.title).font(.headline)
                                Text("Reward: \(chart.reward)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(chart.earnedTokens),
                                             total: Double(chart.targetTokens))
                                    .tint(.orange)
                                Text("\(chart.earnedTokens) of \(chart.targetTokens) tokens")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("reward-chart-\(chart.id)")
                }
            }
            if !store.rewardCollectibles.isEmpty {
                Section("Collected rewards") {
                    ForEach(store.rewardCollectibles) { collected in
                        HStack(spacing: 12) {
                            Text(collected.symbol).font(.title2).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(collected.reward).font(.headline)
                                Text(collected.chartTitle).font(.subheadline).foregroundStyle(.secondary)
                                Text(collected.collectedAt, format: .dateTime.month().day().year())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("Delete record", role: .destructive) {
                                _ = store.deleteRewardCollectible(id: collected.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reward charts")
        .toolbar {
            Button("New reward chart", systemImage: "plus") { showingAdd = true }
                .accessibilityIdentifier("reward-add-chart")
        }
        .sheet(isPresented: $showingAdd) {
            RewardChartEditorView(chart: nil)
        }
    }

    @ViewBuilder
    private func rewardPicture(_ chart: RewardChart) -> some View {
        if let data = chart.photoData {
            AsyncThumbnailImage(data: data) {
                Text(chart.symbol).font(.largeTitle)
            }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
        } else {
            Text(chart.symbol)
                .font(.largeTitle)
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
        }
    }
}
