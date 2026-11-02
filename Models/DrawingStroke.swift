import SwiftUI

struct DrawingPoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(_ location: CGPoint, in size: CGSize) {
        x = min(1, max(0, Double(location.x / max(size.width, 1))))
        y = min(1, max(0, Double(location.y / max(size.height, 1))))
    }

    func location(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

enum DrawingInk: String, Codable, CaseIterable {
    case black, blue, red, green, eraser

    var name: String {
        switch self {
        case .black: "Black"
        case .blue: "Blue"
        case .red: "Red"
        case .green: "Green"
        case .eraser: "Eraser"
        }
    }

    var color: Color {
        switch self {
        case .black: .black
        case .blue: Color(red: 0.05, green: 0.25, blue: 0.9)
        case .red: Color(red: 0.75, green: 0.08, blue: 0.1)
        case .green: Color(red: 0.02, green: 0.45, blue: 0.2)
        case .eraser: .white
        }
    }
}

struct DrawingStroke: Codable, Equatable {
    var points: [DrawingPoint]
    var ink: DrawingInk
    var width: Double
}
