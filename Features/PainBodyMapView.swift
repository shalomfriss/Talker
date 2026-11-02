import SwiftUI

struct PainBodyMapView: View {
    @Binding var selectedLocations: Set<PainLocation>
    @Binding var showingBack: Bool
    @Binding var showingDetails: Bool
    let language: String
    let highlightedLocation: PainLocation?
    let highlightedSide: Bool?
    let detailsHighlighted: Bool
    let highContrast: Bool

    private var detailCount: Int {
        selectedLocations.filter { $0.broadArea != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where does it hurt?")
                .font(.headline)
            Text("Choose one or more areas. You can leave this blank if you are not sure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Body view", selection: $showingBack) {
                Text("Front").tag(false)
                Text("Back").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pain-body-side")
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(highlightedSide != nil
                    ? (highContrast ? Color.black : Color.orange) : .clear, lineWidth: 4))
            .id("pain-scan-side")
            VStack(spacing: 8) {
                area(.head)
                    .frame(maxWidth: 150)
                area(.neck)
                    .frame(maxWidth: 150)
                HStack(alignment: .center, spacing: 8) {
                    area(.leftArm)
                    VStack(spacing: 8) {
                        area(showingBack ? .upperBack : .chest)
                        area(showingBack ? .lowerBack : .stomach)
                    }
                    area(.rightArm)
                }
                HStack(spacing: 26) {
                    area(.leftLeg)
                    area(.rightLeg)
                }
            }
            .padding(14)
            .background(Color.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            DisclosureGroup(isExpanded: $showingDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    detailGroup(language == "es" ? "Cara y cuello" : "Face and neck",
                                locations: [.forehead, .eyes, .ears, .teeth, .throat])
                    detailGroup(language == "es" ? "Brazos y manos" : "Arms and hands",
                                locations: [.leftShoulder, .rightShoulder, .leftHand, .rightHand])
                    detailGroup(language == "es" ? "Piernas y pies" : "Legs and feet",
                                locations: [.leftKnee, .rightKnee, .leftFoot, .rightFoot])
                    detailGroup(language == "es" ? "Pecho y abdomen" : "Chest and belly",
                                locations: [.ribs, .lowerBelly])
                }
                .padding(.top, 12)
            } label: {
                Label(detailCount == 0
                      ? (language == "es" ? "Elegir una zona más específica" : "Choose a more specific spot")
                      : (language == "es" ? "Zonas específicas: \(detailCount)"
                         : "Specific spots: \(detailCount)"),
                      systemImage: "scope")
                    .font(.headline)
            }
            .accessibilityIdentifier("pain-specific-areas")
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(detailsHighlighted
                    ? (highContrast ? Color.black : Color.orange) : .clear, lineWidth: 4))
            .id("pain-scan-details")
        }
        .frame(maxWidth: 520)
    }

    private func detailGroup(_ title: String, locations: [PainLocation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                ForEach(locations) { location in area(location) }
            }
        }
    }

    private func area(_ location: PainLocation) -> some View {
        PainAreaButton(location: location, language: language,
                       isSelected: selectedLocations.contains(location),
                       isScanHighlighted: highlightedLocation == location,
                       highContrast: highContrast) {
            selectedLocations = PainLocation.toggled(location, in: selectedLocations)
        }
        .id("pain-scan-location-\(location.rawValue)")
    }
}
