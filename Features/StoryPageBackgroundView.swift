import SwiftUI

struct StoryPageBackgroundView: View {
    let style: StoryBackgroundStyle
    let photoData: Data?

    var body: some View {
        Group {
            switch style {
            case .plain:
                Color.white
            case .cream:
                Color(red: 0.98, green: 0.94, blue: 0.84)
            case .mint:
                Color(red: 0.86, green: 0.96, blue: 0.90)
            case .sky:
                LinearGradient(colors: [Color(red: 0.84, green: 0.94, blue: 1.0),
                                        Color(red: 0.93, green: 0.89, blue: 0.99)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            case .sunset:
                LinearGradient(colors: [Color(red: 1.0, green: 0.91, blue: 0.78),
                                        Color(red: 0.99, green: 0.83, blue: 0.87)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            case .photo:
                if let photoData, let image = UIImage(data: photoData) {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else {
                    Color.white
                }
            }
        }
        .accessibilityHidden(true)
    }
}
