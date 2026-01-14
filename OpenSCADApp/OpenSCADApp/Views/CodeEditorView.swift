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

    // Store reference to coordinator in textView for completion handling
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
    private let completionProvider = OpenSCADCompletionProvider()
    private var isUpdating = false

    // Completion popup
    private var completionPopup: CompletionPopupView?
    private var completionPrefix: String = ""
    private var completionStartLocation: Int = 0

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

      // Update completion suggestions
      updateCompletions(for: textView)
    }

    func textView(
      _ textView: NSTextView,
      doCommandBy commandSelector: Selector
    ) -> Bool {
      // Handle completion popup key events
      if completionPopup != nil {
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
          return handleCompletionKeyDown(keyCode: 125)
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
          return handleCompletionKeyDown(keyCode: 126)
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
          return handleCompletionKeyDown(keyCode: 36)
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
          return handleCompletionKeyDown(keyCode: 48)
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
          dismissCompletion()
          return true
        }
      }

      // Handle Escape to dismiss completion
      if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
        if completionPopup != nil {
          dismissCompletion()
          return true
        }
      }

      return false
    }

    // Handle Ctrl+Space to trigger completion manually
    func textView(
      _ textView: NSTextView,
      shouldChangeTextIn affectedCharRange: NSRange,
      replacementString: String?
    ) -> Bool {
      return true
    }

    // MARK: - Completion Methods

    private func updateCompletions(for textView: NSTextView) {
      let cursorPosition = textView.selectedRange().location

      // Extract the word being typed
      guard let prefix = completionProvider.extractPrefix(from: textView.string, at: cursorPosition)
      else {
        dismissCompletion()
        return
      }

      // Get matching completions
      let completions = completionProvider.completions(for: prefix)

      if completions.isEmpty {
        dismissCompletion()
        return
      }

      // Update or show completion popup
      completionPrefix = prefix
      completionStartLocation = cursorPosition - prefix.count

      if completionPopup == nil {
        showCompletionPopup(for: textView, with: completions)
      } else {
        completionPopup?.updateCompletions(
          completions,
          onSelect: { [weak self] item in
            self?.insertCompletion(item)
          },
          onDismiss: { [weak self] in
            self?.dismissCompletion()
          }
        )
      }
    }

    private func showCompletionPopup(for textView: NSTextView, with completions: [CompletionItem]) {
      guard let window = textView.window else { return }

      // Get cursor position in screen coordinates
      let cursorRect = textView.firstRect(
        forCharacterRange: textView.selectedRange(), actualRange: nil)

      let popupWidth: CGFloat = 250
      let popupHeight: CGFloat = min(CGFloat(completions.count) * 24 + 8, 200)

      // Create popup
      let popup = CompletionPopupView(
        frame: NSRect(x: 0, y: 0, width: popupWidth, height: popupHeight))
      popup.updateCompletions(
        completions,
        onSelect: { [weak self] item in
          self?.insertCompletion(item)
        },
        onDismiss: { [weak self] in
          self?.dismissCompletion()
        }
      )

      // Position popup below cursor
      var popupOrigin = cursorRect.origin
      popupOrigin.y -= popupHeight + 4  // Below the line

      // Ensure popup stays within window bounds
      let screenFrame = window.screen?.visibleFrame ?? NSRect.zero
      if popupOrigin.y < screenFrame.minY {
        // Show above cursor if not enough space below
        popupOrigin.y = cursorRect.maxY + 4
      }
      if popupOrigin.x + popupWidth > screenFrame.maxX {
        popupOrigin.x = screenFrame.maxX - popupWidth - 10
      }

      // Convert to textView coordinates
      let popupFrame = NSRect(
        origin: popupOrigin, size: NSSize(width: popupWidth, height: popupHeight))
      let localFrame = textView.convert(popupFrame, from: nil)

      popup.frame = localFrame
      textView.addSubview(popup)

      completionPopup = popup
    }

    private func handleCompletionKeyDown(keyCode: UInt16) -> Bool {
      guard let popup = completionPopup else { return false }

      let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "",
        charactersIgnoringModifiers: "",
        isARepeat: false,
        keyCode: keyCode
      )!

      return popup.handleKeyDown(event)
    }

    private func insertCompletion(_ item: CompletionItem) {
      guard let textView = textView else { return }

      // Calculate the range to replace (the prefix that was typed)
      let replaceRange = NSRange(location: completionStartLocation, length: completionPrefix.count)

      // Insert the completion text
      if textView.shouldChangeText(in: replaceRange, replacementString: item.insertText) {
        textView.replaceCharacters(in: replaceRange, with: item.insertText)
        textView.didChangeText()
      }

      dismissCompletion()
    }

    private func dismissCompletion() {
      completionPopup?.removeFromSuperview()
      completionPopup = nil
      completionPrefix = ""
      completionStartLocation = 0
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
