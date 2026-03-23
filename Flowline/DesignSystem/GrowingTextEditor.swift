import SwiftUI

// MARK: - Cross-platform growing text editor
// macOS: NSViewRepresentable wrapping NSTextView (send on Return, newline on Shift+Return)
// iOS:   UIViewRepresentable wrapping UITextView (send on Return)

#if os(macOS)
import AppKit

struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var minHeight: CGFloat = 20
    var maxHeight: CGFloat = 110
    var font: NSFont = .systemFont(ofSize: 14)
    var onSend: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = font
        textView.textColor = NSColor(FlowLineTheme.mainTxt)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
        recalcHeight(textView)
    }

    private func recalcHeight(_ textView: NSTextView) {
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let h = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? minHeight
        let newHeight = max(minHeight, min(h, maxHeight))
        DispatchQueue.main.async {
            if abs(self.height - newHeight) > 0.5 { self.height = newHeight }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextEditor
        init(_ parent: GrowingTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            tv.layoutManager?.ensureLayout(for: tv.textContainer!)
            let h = tv.layoutManager?.usedRect(for: tv.textContainer!).height ?? parent.minHeight
            let newHeight = max(parent.minHeight, min(h, parent.maxHeight))
            DispatchQueue.main.async { self.parent.height = newHeight }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) { return false }
                parent.onSend()
                return true
            }
            return false
        }
    }
}

#else
import UIKit

struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var minHeight: CGFloat = 20
    var maxHeight: CGFloat = 110
    var font: UIFont = .systemFont(ofSize: 14)
    var onSend: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textColor = UIColor(FlowLineTheme.mainTxt)
        tv.font = font
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.returnKeyType = .send
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
        recalcHeight(tv)
    }

    private func recalcHeight(_ tv: UITextView) {
        let size = tv.sizeThatFits(CGSize(width: tv.frame.width, height: .infinity))
        let newHeight = max(minHeight, min(size.height, maxHeight))
        DispatchQueue.main.async {
            if abs(self.height - newHeight) > 0.5 { self.height = newHeight }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextEditor
        init(_ parent: GrowingTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
            let newHeight = max(parent.minHeight, min(size.height, parent.maxHeight))
            DispatchQueue.main.async { self.parent.height = newHeight }
        }

        // Return key = send (no shift+return on iOS software keyboard)
        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSend()
                return false
            }
            return true
        }
    }
}
#endif
