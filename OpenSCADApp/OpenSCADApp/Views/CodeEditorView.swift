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

    // Store reference to textView in coordinator for completion handling
    context.coordinator.textView = textView

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
    private var isUpdating = false

    // Code completion support
    private let completionProvider = CodeCompletionProvider()
    private let completionPopup = CodeCompletionPopup()
    private var completionStartIndex: Int = 0

    init(_ parent: CodeEditorView) {
      self.parent = parent
      super.init()

      // Set up keyboard event monitoring for completion navigation
      NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        return self?.handleKeyEvent(event) ?? event
      }
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

      // Trigger code completion
      triggerCompletion(in: textView)
    }

    // MARK: - Code Completion

    private func triggerCompletion(in textView: NSTextView) {
      let text = textView.string
      let cursorPosition = textView.selectedRange().location

      // Check if we should show completions
      guard completionProvider.shouldTriggerCompletion(in: text, at: cursorPosition),
        let (partialWord, startIndex) = completionProvider.extractPartialWord(
          from: text, at: cursorPosition)
      else {
        completionPopup.hide()
        return
      }

      completionStartIndex = startIndex

      // Get completions
      let completions = completionProvider.completions(for: partialWord)

      if completions.isEmpty {
        completionPopup.hide()
        return
      }

      // Calculate popup position
      let position = calculatePopupPosition(for: textView, at: cursorPosition)

      // Show or update the popup
      if completionPopup.isVisible {
        completionPopup.updateCompletions(completions)
      } else {
        completionPopup.show(
          completions: completions,
          at: position,
          in: textView.window,
          onSelect: { [weak self] item in
            self?.insertCompletion(item: item, in: textView)
          },
          onDismiss: {}
        )
      }
    }

    private func calculatePopupPosition(for textView: NSTextView, at cursorPosition: Int) -> NSPoint
    {
      guard let layoutManager = textView.layoutManager,
        let textContainer = textView.textContainer
      else {
        return .zero
      }

      // Get the glyph range for the cursor position
      let glyphIndex = layoutManager.glyphIndexForCharacter(at: cursorPosition)
      let boundingRect = layoutManager.boundingRect(
        forGlyphRange: NSRange(location: glyphIndex, length: 1),
        in: textContainer
      )

      // Convert to window coordinates
      var point = boundingRect.origin
      point.x += textView.textContainerInset.width
      point.y += textView.textContainerInset.height + boundingRect.height

      // Convert from text view to window coordinates
      point = textView.convert(point, to: nil)

      // Convert from window to screen coordinates
      if let window = textView.window {
        point = window.convertPoint(toScreen: point)
      }

      return point
    }

    private func insertCompletion(
      item: CodeCompletionProvider.CompletionItem, in textView: NSTextView
    ) {
      let cursorPosition = textView.selectedRange().location

      // Calculate range to replace (the partial word)
      let replaceRange = NSRange(
        location: completionStartIndex, length: cursorPosition - completionStartIndex)

      // Insert the completion text
      if textView.shouldChangeText(in: replaceRange, replacementString: item.insertText) {
        textView.replaceCharacters(in: replaceRange, with: item.insertText)
        textView.didChangeText()

        // Position cursor appropriately
        // If the insert text contains (), position cursor inside
        if item.insertText.contains("(") {
          if let parenIndex = item.insertText.firstIndex(of: "(") {
            let offset = item.insertText.distance(from: item.insertText.startIndex, to: parenIndex)
            let newCursorPosition = completionStartIndex + offset + 1
            textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
          }
        }
      }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
      guard completionPopup.isVisible else {
        return event
      }

      // Handle completion navigation keys
      switch event.keyCode {
      case 125:  // Down arrow
        completionPopup.selectNext()
        return nil

      case 126:  // Up arrow
        completionPopup.selectPrevious()
        return nil

      case 36:  // Return/Enter
        completionPopup.confirmSelection()
        return nil

      case 48:  // Tab
        completionPopup.confirmSelection()
        return nil

      case 53:  // Escape
        completionPopup.hide()
        return nil

      default:
        return event
      }
    }

    // MARK: - NSTextViewDelegate Methods

    func textView(
      _ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
      replacementString: String?
    ) -> Bool {
      // Hide completion popup on certain characters that typically end a word
      if let str = replacementString, str.count == 1 {
        let char = str.first!
        if char == " " || char == ")" || char == ";" || char == "\n" || char == ","
          || char == "{"
          || char == "}"
        {
          completionPopup.hide()
        }
      }
      return true
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
