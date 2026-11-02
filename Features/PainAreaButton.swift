import SwiftUI

struct PainAreaButton: View {
    let location: PainLocation
    let language: String
    let isSelected: Bool
    let isScanHighlighted: Bool
    let highContrast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if isSelected { Image(systemName: "checkmark.circle.fill").accessibilityHidden(true) }
                Text(location.label(language: language))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.indigo.opacity(0.22) : Color.white,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isScanHighlighted ? (highContrast ? Color.black : Color.orange)
                              : (isSelected ? Color.indigo : Color.gray.opacity(0.35)),
                              lineWidth: isScanHighlighted ? 4 : 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(location.label(language: language))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("pain-area-\(location.rawValue)")
    }
}
