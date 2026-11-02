import SwiftUI

struct DrawingSurface: View {
    let strokes: [DrawingStroke]
    var activeStroke: DrawingStroke? = nil

    var body: some View {
        Canvas { context, size in
            for stroke in strokes + (activeStroke.map { [$0] } ?? []) {
                guard let first = stroke.points.first else { continue }
                let firstPoint = first.location(in: size)
                var path = Path()
                if stroke.points.count == 1 {
                    let diameter = stroke.width * min(size.width / 360, size.height / 270)
                    path.addEllipse(in: CGRect(x: firstPoint.x - diameter / 2, y: firstPoint.y - diameter / 2,
                                               width: diameter, height: diameter))
                    context.fill(path, with: .color(stroke.ink.color))
                } else {
                    path.move(to: firstPoint)
                    for point in stroke.points.dropFirst() { path.addLine(to: point.location(in: size)) }
                    context.stroke(path, with: .color(stroke.ink.color),
                                   style: StrokeStyle(lineWidth: stroke.width * min(size.width / 360, size.height / 270),
                                                      lineCap: .round, lineJoin: .round))
                }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.gray.opacity(0.5)))
    }
}
