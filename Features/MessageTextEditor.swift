import SwiftUI
import UIKit

struct MessageTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorOffset: Int?
    var textStyle: UIFont.TextStyle = .title3
    var onUserChange: (String, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: textStyle)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.isScrollEnabled = true
        view.accessibilityLabel = "Type a message"
        view.text = text
        let offset = min(max(cursorOffset ?? text.count, 0), text.count)
        let index = text.index(text.startIndex, offsetBy: offset)
        view.selectedRange = NSRange(location: NSRange(text.startIndex..<index, in: text).length, length: 0)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.font = .preferredFont(forTextStyle: textStyle)
        let offset = min(max(cursorOffset ?? text.count, 0), text.count)
        let index = text.index(text.startIndex, offsetBy: offset)
        let location = NSRange(text.startIndex..<index, in: text).length
        guard view.text != text || view.selectedRange.location != location else { return }
        context.coordinator.isUpdatingView = true
        if view.text != text { view.text = text }
        view.selectedRange = NSRange(location: location, length: 0)
        context.coordinator.isUpdatingView = false
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MessageTextEditor
        var isUpdatingView = false

        init(_ parent: MessageTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            let previous = parent.text
            let current = textView.text ?? ""
            parent.text = current
            updateCursor(from: textView)
            parent.onUserChange(previous, current)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdatingView else { return }
            guard textView.isFirstResponder else { return }
            guard (textView.text ?? "") == parent.text else { return }
            updateCursor(from: textView)
        }

        private func updateCursor(from textView: UITextView) {
            let current = textView.text ?? ""
            let utf16Offset = min(textView.selectedRange.location, (current as NSString).length)
            guard let range = Range(NSRange(location: utf16Offset, length: 0), in: current) else {
                parent.cursorOffset = current.count
                return
            }
            parent.cursorOffset = current.distance(from: current.startIndex, to: range.lowerBound)
        }
    }
}
