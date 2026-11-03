import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: CommunicationStore

    var body: some View {
        List {
            if store.settings.saveHistory || !store.history.isEmpty {
                NavigationLink {
                    LanguageSampleView()
                } label: {
                    Label("Language sample", systemImage: "text.bubble")
                }
                .accessibilityIdentifier("open-language-sample")
            }
            if store.history.isEmpty {
                ContentUnavailableView("No recent messages", systemImage: "clock", description: Text("Saved speech and partner notes will appear here when History is on."))
            } else {
                NavigationLink {
                    SavedMessageInsightsView()
                } label: {
                    Label("Saved message insights", systemImage: "chart.bar.xaxis")
                }
                .accessibilityIdentifier("open-message-insights")
                ForEach(store.history) { entry in
                    HStack(spacing: 12) {
                        Button {
                            store.speak(entry.text)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.text).foregroundStyle(.primary)
                                Text("\(entry.speaker?.title ?? "Speaker not recorded") · \(entry.inputMode?.title ?? "Input not recorded")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(entry.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Speak again")
                        ShareLink(item: entry.text) { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel("Share message")
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deleteHistoryEntry(entry) }
                    }
                }
            }
        }
        .navigationTitle("Recent messages")
        .toolbar {
            if !store.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear all", role: .destructive) { store.clearHistory() }
                }
            }
        }
    }
}

struct SavedMessageInsights {
    struct Day: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    struct RepeatedMessage: Identifiable {
        let text: String
        let count: Int
        let mostRecent: Date
        var id: String { text.lowercased() }
    }

    let days: [Day]
    let total: Int
    let activeDays: Int
    let repeatedMessages: [RepeatedMessage]

    init(history: [SpokenMessage], now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        var dayCounts: [Date: Int] = [:]
        var messages: [String: RepeatedMessage] = [:]

        for entry in history where entry.date <= now && entry.speaker != .partner {
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if entry.date >= firstDay {
                dayCounts[calendar.startOfDay(for: entry.date), default: 0] += 1
            }
            let key = text.lowercased()
            if let previous = messages[key] {
                messages[key] = RepeatedMessage(
                    text: entry.date > previous.mostRecent ? text : previous.text,
                    count: previous.count + 1,
                    mostRecent: max(previous.mostRecent, entry.date))
            } else {
                messages[key] = RepeatedMessage(text: text, count: 1, mostRecent: entry.date)
            }
        }

        days = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.map { Day(date: $0, count: dayCounts[$0, default: 0]) }
        total = days.reduce(0) { $0 + $1.count }
        activeDays = days.filter { $0.count > 0 }.count
        repeatedMessages = messages.values.filter { $0.count > 1 }.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            if $0.mostRecent != $1.mostRecent { return $0.mostRecent > $1.mostRecent }
            return $0.text < $1.text
        }
    }
}

private struct SavedMessageInsightsView: View {
    @EnvironmentObject private var store: CommunicationStore

    var body: some View {
        let insights = SavedMessageInsights(history: store.history)
        let highestCount = max(1, insights.days.map(\.count).max() ?? 0)
        return List {
            Section {
                Text("A local summary of up to 50 saved spoken messages. Private conversations and messages spoken while history was paused are excluded. Counts do not represent all communication.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Last seven days") {
                HStack {
                    Label("\(insights.total) saved messages", systemImage: "bubble.left")
                    Spacer()
                    Text("\(insights.activeDays) active days")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(insights.total) saved messages, \(insights.activeDays) active days")
                .accessibilityIdentifier("message-insights-summary")

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(insights.days) { day in
                        VStack(spacing: 6) {
                            Text("\(day.count)")
                                .font(.caption.weight(.semibold))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(day.count == 0 ? Color.secondary.opacity(0.25) : Color.indigo)
                                .frame(height: max(4, CGFloat(day.count) / CGFloat(highestCount) * 84))
                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(date: .complete, time: .omitted)): \(day.count) saved messages")
                    }
                }
                .frame(height: 125, alignment: .bottom)
            }

            Section("Repeated saved messages") {
                if insights.repeatedMessages.isEmpty {
                    Text("No message has been saved more than once yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(insights.repeatedMessages.prefix(5)) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(message.text)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("\(message.count) times")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if store.phrases.contains(where: { $0.text == message.text }) {
                                Label("In Quick phrases", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Save as Quick phrase", systemImage: "plus.circle") {
                                    store.addPhrase(message.text)
                                }
                                .accessibilityIdentifier("save-insight-phrase-\(message.id)")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Message insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}
