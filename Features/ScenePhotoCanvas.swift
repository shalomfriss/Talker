import AVFoundation
import SwiftUI

struct ScenePhotoCanvas<Marker: View>: View {
    let imageData: Data
    let hotspots: [SceneHotspot]
    var videoPlayer: AVPlayer? = nil
    @ViewBuilder let marker: (SceneHotspot, CGSize) -> Marker

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if let videoPlayer {
                    SceneVideoSurface(player: videoPlayer)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                } else if let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(true)
                }
                ForEach(hotspots) { hotspot in
                    marker(hotspot, geometry.size)
                        .position(x: min(1 - (hotspot.width ?? 0) / 2,
                                         max((hotspot.width ?? 0) / 2, hotspot.x)) * geometry.size.width,
                                  y: min(1 - (hotspot.height ?? 0) / 2,
                                         max((hotspot.height ?? 0) / 2, hotspot.y)) * geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }
}

struct SceneMarkerLabel: View {
    let label: String
    let highContrast: Bool
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var backgroundColorHex: String? = nil

    private var markerColor: Color {
        guard !highContrast, let backgroundColorHex,
              let value = ButtonColorValue(text: backgroundColorHex) else {
            return highContrast ? .black : .white.opacity(0.94)
        }
        return ButtonColorAppearance.color(value)
    }

    private var textColor: Color {
        guard !highContrast else { return .white }
        guard let backgroundColorHex, let value = ButtonColorValue(text: backgroundColorHex) else {
            return .primary
        }
        return value.prefersDarkText ? .black : .white
    }

    var body: some View {
        Text(label)
            .font(height.map { $0 < 34 } == true ? .caption.bold() : .headline)
            .lineLimit(height.map { $0 < 34 } == true ? 1 : 2)
            .minimumScaleFactor(0.55)
            .multilineTextAlignment(.center)
            .padding(.horizontal, width == nil ? 12 : 4)
            .padding(.vertical, height == nil ? 10 : 2)
            .frame(width: width, height: height)
            .foregroundStyle(textColor)
            .background(markerColor,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(highContrast ? Color.white : Color.indigo, lineWidth: 3))
            .shadow(radius: 2)
    }
}
