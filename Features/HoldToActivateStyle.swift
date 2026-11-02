import SwiftUI

struct HoldToActivateStyle: PrimitiveButtonStyle {
    let duration: Double

    func makeBody(configuration: Configuration) -> some View {
        HoldButton(configuration: configuration, duration: duration)
    }

    private struct HoldButton: View {
        let configuration: Configuration
        let duration: Double
        @State private var isPressing = false

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .opacity(isPressing ? 0.6 : 1)
                .onLongPressGesture(minimumDuration: duration, maximumDistance: 20) {
                    configuration.trigger()
                } onPressingChanged: { isPressing = $0 }
        }
    }
}
