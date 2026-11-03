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
            VStack(spacing: 12) {
                Text(language == "es" ? "Toca el cuerpo para elegir una zona" : "Tap the body to choose an area")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                PainSilhouetteMap(selectedLocations: $selectedLocations,
                                  showingBack: showingBack, language: language,
                                  highlightedLocation: highlightedLocation,
                                  highContrast: highContrast)
                Text(language == "es" ? "También puedes elegir por nombre:" : "Or choose by name:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        area(.head)
                        area(.neck)
                        area(.leftArm)
                    }
                    HStack(spacing: 8) {
                        area(showingBack ? .upperBack : .chest)
                        area(showingBack ? .lowerBack : .stomach)
                        area(.rightArm)
                    }
                    HStack(spacing: 8) {
                        area(.leftLeg)
                        area(.rightLeg)
                    }
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

private struct PainSilhouetteMap: View {
    @Binding var selectedLocations: Set<PainLocation>
    let showingBack: Bool
    let language: String
    let highlightedLocation: PainLocation?
    let highContrast: Bool

    private var locations: [PainLocation] {
        [.head, .neck, .leftArm, .rightArm,
         showingBack ? .upperBack : .chest,
         showingBack ? .lowerBack : .stomach,
         .leftLeg, .rightLeg]
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(locations) { location in
                        regionButton(location, in: geometry.size)
                    }
                }
            }
            .frame(width: 300, height: 390)
            HStack {
                Text(language == "es" ? "Izquierda" : "Left")
                Spacer()
                Text(showingBack
                     ? (language == "es" ? "Espalda" : "Back")
                     : (language == "es" ? "Frente" : "Front"))
                Spacer()
                Text(language == "es" ? "Derecha" : "Right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 300)
        }
        .frame(maxWidth: .infinity)
    }

    private func regionButton(_ location: PainLocation, in size: CGSize) -> some View {
        let region = PainSilhouetteRegion(location: location)
        let selected = selectedLocations.contains(location)
        let shape = PainSilhouetteShape(location: location)
        return Button {
            selectedLocations = PainLocation.toggled(location, in: selectedLocations)
        } label: {
            shape
                .fill(highContrast ? (selected ? Color.black : Color.white)
                      : (selected ? Color.indigo.opacity(0.64) : Color.indigo.opacity(0.18)))
                .overlay(shape.stroke(highlightedLocation == location
                                      ? (highContrast ? Color.black : Color.orange)
                                      : (highContrast ? Color.black : Color.indigo.opacity(0.7)),
                                      lineWidth: highlightedLocation == location ? 5 : 2))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: region.width * size.width,
                       height: region.height * size.height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(location.label(language: language))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("pain-map-\(location.rawValue)")
        .position(x: (region.x + region.width / 2) * size.width,
                  y: (region.y + region.height / 2) * size.height)
    }
}

private struct PainSilhouetteRegion {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(location: PainLocation) {
        switch location {
        case .head: (x, y, width, height) = (0.39, 0.01, 0.22, 0.16)
        case .neck: (x, y, width, height) = (0.43, 0.18, 0.14, 0.09)
        case .chest, .upperBack: (x, y, width, height) = (0.33, 0.28, 0.34, 0.18)
        case .stomach, .lowerBack: (x, y, width, height) = (0.36, 0.47, 0.28, 0.18)
        case .leftArm: (x, y, width, height) = (0.15, 0.28, 0.17, 0.34)
        case .rightArm: (x, y, width, height) = (0.68, 0.28, 0.17, 0.34)
        case .leftLeg: (x, y, width, height) = (0.35, 0.66, 0.14, 0.33)
        case .rightLeg: (x, y, width, height) = (0.51, 0.66, 0.14, 0.33)
        default: (x, y, width, height) = (0, 0, 0, 0)
        }
    }
}

private struct PainSilhouetteShape: Shape {
    let location: PainLocation

    func path(in rect: CGRect) -> Path {
        switch location {
        case .head:
            return Path(ellipseIn: rect)
        case .leftArm, .rightArm:
            let left = location == .leftArm
            var path = Path()
            path.move(to: CGPoint(x: left ? rect.maxX : rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: left ? rect.minX + 8 : rect.maxX - 8, y: rect.minY + 8))
            path.addLine(to: CGPoint(x: left ? rect.minX : rect.maxX, y: rect.maxY - 8))
            path.addQuadCurve(to: CGPoint(x: left ? rect.minX + 17 : rect.maxX - 17, y: rect.maxY),
                              control: CGPoint(x: left ? rect.minX + 6 : rect.maxX - 6, y: rect.maxY + 4))
            path.addLine(to: CGPoint(x: left ? rect.maxX : rect.minX, y: rect.minY))
            path.closeSubpath()
            return path
        default:
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.2)
        }
    }
}
