import SwiftUI

struct DrawingShareButton: View {
    let strokes: [DrawingStroke]
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview("Drawing", image: image)) {
                    Label("Share drawing", systemImage: "square.and.arrow.up")
                }
                .disabled(strokes.isEmpty)
            } else {
                Label("Share drawing", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: render)
        .onChange(of: strokes) { _, _ in render() }
    }

    private func render() {
        guard !strokes.isEmpty else { image = nil; return }
        let renderer = ImageRenderer(content:
            DrawingSurface(strokes: strokes)
                .frame(width: 960, height: 720)
                .background(.white))
        renderer.scale = 1
        image = renderer.uiImage.map(Image.init(uiImage:))
    }
}
