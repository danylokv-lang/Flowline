import SwiftUI
import AppKit

struct GrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var minHeight: CGFloat = 20
    var maxHeight: CGFloat = 110
    var font: NSFont = .systemFont(ofSize: 14)
    var onSend: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

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

        // Zero internal padding — this is the key fix
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

        if textView.string != text {
            textView.string = text
        }

        // Measure content height and report back to SwiftUI
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let contentHeight = textView.layoutManager?
            .usedRect(for: textView.textContainer!).height ?? minHeight
        let newHeight = max(minHeight, min(contentHeight, maxHeight))

        DispatchQueue.main.async {
            if abs(self.height - newHeight) > 0.5 {
                self.height = newHeight
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GrowingTextEditor

        init(_ parent: GrowingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Recalculate height on every keystroke
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            let contentHeight = textView.layoutManager?
                .usedRect(for: textView.textContainer!).height ?? parent.minHeight
            let newHeight = max(parent.minHeight, min(contentHeight, parent.maxHeight))

            DispatchQueue.main.async {
                self.parent.height = newHeight
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    return false
                }
                parent.onSend()
                return true
            }
            return false
        }
    }
}
