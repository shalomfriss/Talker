import SwiftUI

struct DrawingDisplayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var facingPartner = false
    let strokes: [DrawingStroke]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                DrawingSurface(strokes: strokes)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .rotationEffect(.degrees(facingPartner ? 180 : 0))
                    .accessibilityLabel("Drawing with \(strokes.count) marks")
                    .accessibilityIdentifier("large-drawing")
                Spacer(minLength: 0)
                Button(facingPartner ? "Face me" : "Face partner", systemImage: "arrow.triangle.2.circlepath") {
                    facingPartner.toggle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("flip-drawing")
                DrawingShareButton(strokes: strokes)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            .padding(20)
            .navigationTitle("Show drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
