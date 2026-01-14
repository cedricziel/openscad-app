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

    // Store reference to text view in coordinator for completion handling
    context.coordinator.textView = textView

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
    weak var textView: NSTextView?
    private let syntaxHighlighter = OpenSCADSyntaxHighlighter()
    private let completionProvider = OpenSCADCompletionProvider()
    private var completionPopup: CompletionPopupView?
    private var isUpdating = false
    private var completionWordRange: NSRange?

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

      // Update completions
      updateCompletions(for: textView)
    }

    // MARK: - Completion Handling

    private func updateCompletions(for textView: NSTextView) {
      let text = textView.string
      let cursorPosition = textView.selectedRange().location

      guard let (prefix, range) = completionProvider.currentWordPrefix(in: text, at: cursorPosition)
      else {
        hideCompletionPopup()
        return
      }

      completionWordRange = range
      let completions = completionProvider.completions(for: prefix, in: text)

      if completions.isEmpty {
        hideCompletionPopup()
        return
      }

      showCompletionPopup(with: completions, for: textView, at: range)
    }

    private func showCompletionPopup(
      with items: [CompletionItem], for textView: NSTextView, at range: NSRange
    ) {
      // Get cursor position in screen coordinates
      guard let layoutManager = textView.layoutManager,
        let textContainer = textView.textContainer
      else {
        return
      }

      let glyphRange = layoutManager.glyphRange(
        forCharacterRange: range, actualCharacterRange: nil)
      var rect = layoutManager.boundingRect(
        forGlyphRange: glyphRange, in: textContainer)

      // Adjust for text container inset
      rect.origin.x += textView.textContainerInset.width
      rect.origin.y += textView.textContainerInset.height

      // Convert to scroll view coordinates
      if let scrollView = textView.enclosingScrollView {
        let pointInScrollView = textView.convert(
          NSPoint(x: rect.origin.x, y: rect.maxY), to: scrollView)

        if completionPopup == nil {
          completionPopup = CompletionPopupView()
        }

        completionPopup?.show(
          items: items,
          at: pointInScrollView,
          in: scrollView,
          onSelect: { [weak self] item in
            self?.insertCompletion(item, in: textView, replacing: range)
          },
          onDismiss: { [weak self] in
            self?.completionWordRange = nil
          }
        )
      }
    }

    private func hideCompletionPopup() {
      completionPopup?.hide()
      completionWordRange = nil
    }

    private func insertCompletion(
      _ item: CompletionItem, in textView: NSTextView, replacing range: NSRange
    ) {
      guard let textStorage = textView.textStorage else { return }

      isUpdating = true
      defer { isUpdating = false }

      // Calculate the insertion text (may need to handle snippets in the future)
      let insertionText = item.insertionText

      // Replace the word prefix with the completion
      textStorage.beginEditing()

      // Store cursor position
      let cursorOffset = findCursorOffset(in: insertionText)

      textStorage.replaceCharacters(in: range, with: insertionText)
      textStorage.endEditing()

      // Update the binding
      parent.text = textView.string

      // Re-apply syntax highlighting
      syntaxHighlighter.applyHighlighting(to: textStorage)

      // Position cursor appropriately
      let newCursorPosition: Int
      if let offset = cursorOffset {
        newCursorPosition = range.location + offset
      } else {
        newCursorPosition = range.location + insertionText.count
      }

      textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
    }

    /// Find a good cursor position within the insertion text
    /// Returns the offset to position the cursor, or nil for end of text
    private func findCursorOffset(in text: String) -> Int? {
      // Position cursor inside parentheses if they exist
      if let parenIndex = text.firstIndex(of: "(") {
        let nextIndex = text.index(after: parenIndex)
        if nextIndex < text.endIndex && text[nextIndex] == ")" {
          // Empty parentheses - position inside
          return text.distance(from: text.startIndex, to: nextIndex)
        } else if nextIndex < text.endIndex {
          // Has content - position after opening paren
          return text.distance(from: text.startIndex, to: nextIndex)
        }
      }

      // Position cursor inside braces if they exist
      if let braceIndex = text.firstIndex(of: "{") {
        let nextIndex = text.index(after: braceIndex)
        // Skip whitespace and newlines to find content area
        var searchIndex = nextIndex
        while searchIndex < text.endIndex
          && (text[searchIndex] == " " || text[searchIndex] == "\n")
        {
          searchIndex = text.index(after: searchIndex)
        }
        return text.distance(from: text.startIndex, to: searchIndex)
      }

      // Position cursor inside angle brackets for use/include
      if let angleIndex = text.firstIndex(of: "<") {
        let nextIndex = text.index(after: angleIndex)
        if nextIndex < text.endIndex && text[nextIndex] == ">" {
          return text.distance(from: text.startIndex, to: nextIndex)
        }
      }

      // Position cursor inside quotes
      if let quoteIndex = text.firstIndex(of: "\"") {
        let afterQuote = text.index(after: quoteIndex)
        if afterQuote < text.endIndex,
          let closingQuote = text[afterQuote...].firstIndex(of: "\"")
        {
          return text.distance(from: text.startIndex, to: closingQuote)
        }
      }

      return nil
    }

    // MARK: - Key Event Handling

    func textView(
      _ textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
      // Handle completion navigation keys
      if let popup = completionPopup, popup.isVisible {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
          popup.selectNext()
          return true

        case #selector(NSResponder.moveUp(_:)):
          popup.selectPrevious()
          return true

        case #selector(NSResponder.insertNewline(_:)),
          #selector(NSResponder.insertTab(_:)):
          popup.confirmSelection()
          return true

        case #selector(NSResponder.cancelOperation(_:)),
          #selector(NSResponder.complete(_:)):
          hideCompletionPopup()
          return true

        default:
          break
        }
      } else {
        // Trigger completion manually with Escape or Ctrl+Space
        if commandSelector == #selector(NSResponder.complete(_:)) {
          updateCompletions(for: textView)
          return true
        }
      }

      return false
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      // Hide completion popup if selection changes significantly
      guard let textView = notification.object as? NSTextView else { return }

      if let popup = completionPopup, popup.isVisible {
        let currentPosition = textView.selectedRange().location

        // Check if cursor moved outside the completion word
        if let wordRange = completionWordRange {
          if currentPosition < wordRange.location
            || currentPosition > wordRange.location + wordRange.length + 20
          {
            hideCompletionPopup()
          }
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
