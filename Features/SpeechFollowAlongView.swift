import SwiftUI

struct SpeechFollowAlongView: View {
    let state: SpeechHighlightState
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Speaking")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(highlightedText)
                .font(large ? .system(size: 42, weight: .bold, design: .rounded) : .title3)
                .frame(maxWidth: .infinity, alignment: large ? .center : .leading)
                .multilineTextAlignment(large ? .center : .leading)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speaking: \(state.text)")
        .accessibilityIdentifier("speech-follow-along")
    }

    private var highlightedText: AttributedString {
        guard let range = state.range,
              let stringRange = Range(range, in: state.text) else {
            return AttributedString(state.text)
        }
        var result = AttributedString(String(state.text[..<stringRange.lowerBound]))
        var active = AttributedString(String(state.text[stringRange]))
        active.backgroundColor = .yellow
        active.foregroundColor = .black
        result.append(active)
        result.append(AttributedString(String(state.text[stringRange.upperBound...])))
        return result
    }
}
