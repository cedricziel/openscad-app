import AppKit
import SwiftUI

struct CodeEditorView: NSViewRepresentable {
  @Binding var text: String

  private let syntaxHighlighter = OpenSCADSyntaxHighlighter()

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    guard let textView = scrollView.documentView as? NSTextView else {
      return scrollView
    }

    textView.isEditable = true
    textView.isSelectable = true
    textView.allowsUndo = true
    textView.isRichText = true  // Enable rich text for syntax highlighting
    textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    textView.backgroundColor = NSColor.textBackgroundColor
    textView.textColor = NSColor.textColor
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false

    textView.textContainerInset = NSSize(width: 8, height: 8)
    textView.delegate = context.coordinator

    // Set initial text with syntax highlighting
    if let textStorage = textView.textStorage {
      let highlightedText = syntaxHighlighter.highlight(text)
      textStorage.setAttributedString(highlightedText)
    }

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }

    if textView.string != text {
      let selectedRanges = textView.selectedRanges

      // Apply syntax highlighting to the new text
      if let textStorage = textView.textStorage {
        let highlightedText = syntaxHighlighter.highlight(text)
        textStorage.setAttributedString(highlightedText)
      }

      // Restore selection, ensuring ranges are valid
      let validRanges = selectedRanges.compactMap { rangeValue -> NSValue? in
        let range = rangeValue.rangeValue
        if range.location <= text.utf16.count {
          let adjustedLength = min(range.length, text.utf16.count - range.location)
          return NSValue(range: NSRange(location: range.location, length: adjustedLength))
        }
        return nil
      }

      if !validRanges.isEmpty {
        textView.selectedRanges = validRanges
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CodeEditorView
    private let syntaxHighlighter = OpenSCADSyntaxHighlighter()
    private var isUpdating = false

    init(_ parent: CodeEditorView) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      guard !isUpdating else { return }

      isUpdating = true
      defer { isUpdating = false }

      // Update the binding with the plain text
      parent.text = textView.string

      // Apply syntax highlighting
      if let textStorage = textView.textStorage {
        let selectedRanges = textView.selectedRanges
        syntaxHighlighter.applyHighlighting(to: textStorage)

        // Restore cursor position after highlighting
        let validRanges = selectedRanges.compactMap { rangeValue -> NSValue? in
          let range = rangeValue.rangeValue
          if range.location <= textStorage.length {
            let adjustedLength = min(range.length, textStorage.length - range.location)
            return NSValue(range: NSRange(location: range.location, length: adjustedLength))
          }
          return nil
        }

        if !validRanges.isEmpty {
          textView.selectedRanges = validRanges
        }
      }
    }
  }
}

#Preview {
  CodeEditorView(
    text: .constant(
      """
      // OpenSCAD Example
      $fn = 100;

      module rounded_cube(size, radius) {
          hull() {
              for (x = [radius, size[0] - radius])
                  for (y = [radius, size[1] - radius])
                      for (z = [radius, size[2] - radius])
                          translate([x, y, z])
                              sphere(r = radius);
          }
      }

      difference() {
          rounded_cube([30, 20, 10], 2);
          translate([5, 5, 2])
              cube([20, 10, 8]);
      }
      """)
  )
  .frame(width: 500, height: 400)
}
