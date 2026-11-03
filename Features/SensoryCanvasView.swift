import SwiftUI
import UIKit
import Combine

private extension SensoryIntensity {
    var color: Color {
        switch self {
        case .calm: Color(red: 0.12, green: 0.52, blue: 0.55)
        case .balanced: .indigo
        case .lively: Color(red: 0.85, green: 0.40, blue: 0.18)
        }
    }
}

private struct SensoryRipple: Identifiable {
    let id = UUID()
    let location: CGPoint
    let createdAt: Date
}

struct SensoryCanvasView: View {
    @EnvironmentObject private var store: CommunicationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripples: [SensoryRipple] = []
    @State private var lastTouch: CGPoint?
    @State private var lastTouchAt = Date.distantPast
    private let cleanupTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var intensity: SensoryIntensity { store.settings.sensoryIntensity }
    private var moves: Bool { store.settings.sensoryMotionEnabled && !reduceMotion }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Touch or drag to make soft circles. There is no timer or goal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GeometryReader { geometry in
                    ZStack {
                        Color(uiColor: .secondarySystemBackground)
                        if moves && !ripples.isEmpty {
                            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                                Canvas { context, size in
                                    drawRipples(in: context, size: size, now: timeline.date, animated: true)
                                }
                            }
                            .onReceive(cleanupTicker) { date in
                                ripples.removeAll { date.timeIntervalSince($0.createdAt) >= intensity.duration }
                            }
                        } else {
                            Canvas { context, size in
                                drawRipples(in: context, size: size, now: Date(), animated: false)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in addRipple(at: value.location, size: geometry.size) }
                        .onEnded { _ in lastTouch = nil })
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(intensity.color.opacity(0.18), lineWidth: 1))
                    .accessibilityLabel("Sensory touch canvas")
                    .accessibilityHint("Touch or drag to make circles. Use Add a ripple if touch gestures are difficult.")
                    .accessibilityIdentifier("sensory-canvas")
                }
                .frame(height: 390)

                HStack(spacing: 12) {
                    Button("Add a ripple", systemImage: "circle.dotted") {
                        addRipple(atNormalized: CGPoint(x: 0.5, y: 0.5))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("sensory-add-ripple")
                    Button("Clear canvas", systemImage: "xmark.circle") {
                        ripples.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(ripples.isEmpty)
                    .accessibilityIdentifier("sensory-clear")
                }
                .controlSize(.large)

                Picker("Visual intensity", selection: $store.settings.sensoryIntensity) {
                    ForEach(SensoryIntensity.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sensory-intensity")

                Toggle("Animate circles", isOn: $store.settings.sensoryMotionEnabled)
                    .accessibilityIdentifier("sensory-motion")
                Toggle("Gentle haptics", isOn: $store.settings.sensoryHapticsEnabled)
                    .accessibilityIdentifier("sensory-haptics")
                if reduceMotion {
                    Text("Your device's Reduce Motion setting is on, so circles stay still.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 650)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sensory canvas")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.settings.sensoryMotionEnabled) { _, _ in ripples.removeAll() }
        .onChange(of: reduceMotion) { _, _ in ripples.removeAll() }
        .onDisappear { ripples.removeAll() }
    }

    private func addRipple(at point: CGPoint, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let normalized = CGPoint(x: min(max(point.x / size.width, 0), 1),
                                 y: min(max(point.y / size.height, 0), 1))
        addRipple(atNormalized: normalized)
    }

    private func addRipple(atNormalized point: CGPoint) {
        let now = Date()
        if let lastTouch,
           now.timeIntervalSince(lastTouchAt) < 0.12,
           hypot(point.x - lastTouch.x, point.y - lastTouch.y) < 0.045 { return }
        lastTouch = point
        lastTouchAt = now
        ripples.append(SensoryRipple(location: point, createdAt: now))
        if ripples.count > 24 { ripples.removeFirst(ripples.count - 24) }
        if store.settings.sensoryHapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
    }

    private func drawRipples(in context: GraphicsContext, size: CGSize, now: Date, animated: Bool) {
        let width = min(size.width, size.height)
        for ripple in ripples {
            let elapsed = max(0, now.timeIntervalSince(ripple.createdAt))
            if animated && elapsed > intensity.duration { continue }
            let progress = animated ? min(elapsed / intensity.duration, 1) : 0.25
            let center = CGPoint(x: ripple.location.x * size.width, y: ripple.location.y * size.height)
            let radius = width * (0.07 + progress * 0.38)
            let opacity = animated ? 0.68 * (1 - progress) : 0.45
            for fraction in [1.0, 0.62] {
                let ringRadius = radius * fraction
                let rect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                  width: ringRadius * 2, height: ringRadius * 2)
                context.stroke(Path(ellipseIn: rect),
                               with: .color(intensity.color.opacity(opacity * fraction)),
                               lineWidth: intensity == .lively ? 5 : 3)
            }
            let dot = CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
            context.fill(Path(ellipseIn: dot), with: .color(intensity.color.opacity(opacity)))
        }
    }
}
