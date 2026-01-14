import AppKit
import SwiftUI

/// A popup window that displays code completion suggestions
final class CodeCompletionPopup: NSObject {

  // MARK: - Properties

  private var window: NSWindow?
  private var tableView: NSTableView?
  private var scrollView: NSScrollView?
  private var completions: [CodeCompletionProvider.CompletionItem] = []
  private var selectedIndex: Int = 0
  private var onSelect: ((CodeCompletionProvider.CompletionItem) -> Void)?
  private var onDismiss: (() -> Void)?

  private let rowHeight: CGFloat = 24
  private let maxVisibleRows: Int = 8
  private let popupWidth: CGFloat = 320

  // MARK: - Public Methods

  /// Show the completion popup at the specified screen position
  /// - Parameters:
  ///   - completions: Array of completion items to display
  ///   - position: Screen position (bottom-left of popup)
  ///   - parentWindow: The parent window to attach to
  ///   - onSelect: Callback when an item is selected
  ///   - onDismiss: Callback when popup is dismissed
  func show(
    completions: [CodeCompletionProvider.CompletionItem],
    at position: NSPoint,
    in parentWindow: NSWindow?,
    onSelect: @escaping (CodeCompletionProvider.CompletionItem) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.completions = completions
    self.onSelect = onSelect
    self.onDismiss = onDismiss
    self.selectedIndex = 0

    guard !completions.isEmpty else {
      hide()
      return
    }

    if window == nil {
      setupWindow()
    }

    updateContent()

    // Calculate popup height based on number of items
    let visibleRows = min(completions.count, maxVisibleRows)
    let popupHeight = CGFloat(visibleRows) * rowHeight + 4  // +4 for border

    // Position the window
    var adjustedPosition = position
    adjustedPosition.y -= popupHeight  // Position below the cursor

    // Make sure popup stays on screen
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame

      // Adjust horizontal position if needed
      if adjustedPosition.x + popupWidth > screenFrame.maxX {
        adjustedPosition.x = screenFrame.maxX - popupWidth
      }

      // If popup would go off bottom of screen, show above cursor instead
      if adjustedPosition.y < screenFrame.minY {
        adjustedPosition.y = position.y + 20  // Show above cursor
      }
    }

    window?.setFrame(
      NSRect(x: adjustedPosition.x, y: adjustedPosition.y, width: popupWidth, height: popupHeight),
      display: true
    )

    if let parentWindow = parentWindow {
      parentWindow.addChildWindow(window!, ordered: .above)
    }

    window?.orderFront(nil)
  }

  /// Hide the completion popup
  func hide() {
    if let window = window, let parent = window.parent {
      parent.removeChildWindow(window)
    }
    window?.orderOut(nil)
    onDismiss?()
  }

  /// Update completions without repositioning the window
  func updateCompletions(_ newCompletions: [CodeCompletionProvider.CompletionItem]) {
    self.completions = newCompletions
    self.selectedIndex = 0

    if completions.isEmpty {
      hide()
      return
    }

    updateContent()

    // Update window height
    let visibleRows = min(completions.count, maxVisibleRows)
    let popupHeight = CGFloat(visibleRows) * rowHeight + 4

    if let frame = window?.frame {
      let newFrame = NSRect(
        x: frame.origin.x,
        y: frame.origin.y + frame.height - popupHeight,
        width: popupWidth,
        height: popupHeight
      )
      window?.setFrame(newFrame, display: true)
    }
  }

  /// Move selection up
  func selectPrevious() {
    guard !completions.isEmpty else { return }
    selectedIndex = (selectedIndex - 1 + completions.count) % completions.count
    tableView?.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
    tableView?.scrollRowToVisible(selectedIndex)
  }

  /// Move selection down
  func selectNext() {
    guard !completions.isEmpty else { return }
    selectedIndex = (selectedIndex + 1) % completions.count
    tableView?.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
    tableView?.scrollRowToVisible(selectedIndex)
  }

  /// Confirm selection and insert the completion
  func confirmSelection() {
    guard !completions.isEmpty, selectedIndex < completions.count else { return }
    let item = completions[selectedIndex]
    onSelect?(item)
    hide()
  }

  /// Check if popup is currently visible
  var isVisible: Bool {
    window?.isVisible ?? false
  }

  /// Get the currently selected item
  var selectedItem: CodeCompletionProvider.CompletionItem? {
    guard !completions.isEmpty, selectedIndex < completions.count else { return nil }
    return completions[selectedIndex]
  }

  // MARK: - Private Methods

  private func setupWindow() {
    // Create the window
    let contentRect = NSRect(
      x: 0, y: 0, width: popupWidth, height: rowHeight * CGFloat(maxVisibleRows))
    let window = NSWindow(
      contentRect: contentRect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    window.level = .popUpMenu
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true

    // Create container view with rounded corners
    let containerView = NSVisualEffectView(frame: contentRect)
    containerView.material = .popover
    containerView.state = .active
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = 6
    containerView.layer?.masksToBounds = true
    containerView.layer?.borderWidth = 1
    containerView.layer?.borderColor = NSColor.separatorColor.cgColor

    // Create table view
    let tableView = NSTableView()
    tableView.headerView = nil
    tableView.rowHeight = rowHeight
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .regular
    tableView.delegate = self
    tableView.dataSource = self
    tableView.target = self
    tableView.doubleAction = #selector(tableViewDoubleClicked)

    // Add columns
    let iconColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
    iconColumn.width = 24
    iconColumn.minWidth = 24
    iconColumn.maxWidth = 24
    tableView.addTableColumn(iconColumn)

    let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
    textColumn.width = popupWidth - 24 - 100
    tableView.addTableColumn(textColumn)

    let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
    detailColumn.width = 100
    tableView.addTableColumn(detailColumn)

    // Create scroll view
    let scrollView = NSScrollView(frame: contentRect.insetBy(dx: 2, dy: 2))
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.autoresizingMask = [.width, .height]

    containerView.addSubview(scrollView)
    window.contentView = containerView

    self.window = window
    self.tableView = tableView
    self.scrollView = scrollView
  }

  private func updateContent() {
    tableView?.reloadData()
    if !completions.isEmpty {
      tableView?.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
    }
  }

  @objc private func tableViewDoubleClicked() {
    confirmSelection()
  }
}

// MARK: - NSTableViewDataSource

extension CodeCompletionPopup: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    completions.count
  }
}

// MARK: - NSTableViewDelegate

extension CodeCompletionPopup: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    guard row < completions.count else { return nil }

    let item = completions[row]
    let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

    let cellView: NSTableCellView
    if let reusedView = tableView.makeView(withIdentifier: identifier, owner: nil)
      as? NSTableCellView
    {
      cellView = reusedView
    } else {
      cellView = NSTableCellView()
      cellView.identifier = identifier

      let textField = NSTextField(labelWithString: "")
      textField.translatesAutoresizingMaskIntoConstraints = false
      textField.cell?.truncatesLastVisibleLine = true
      textField.cell?.lineBreakMode = .byTruncatingTail
      cellView.addSubview(textField)
      cellView.textField = textField

      NSLayoutConstraint.activate([
        textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
        textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
      ])
    }

    switch tableColumn?.identifier.rawValue {
    case "icon":
      cellView.textField?.stringValue = item.category.icon
      cellView.textField?.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
      cellView.textField?.textColor = categoryColor(for: item.category)
      cellView.textField?.alignment = .center

    case "text":
      cellView.textField?.stringValue = item.displayText
      cellView.textField?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
      cellView.textField?.textColor = .textColor

    case "detail":
      cellView.textField?.stringValue = item.detail ?? ""
      cellView.textField?.font = .systemFont(ofSize: 10)
      cellView.textField?.textColor = .secondaryLabelColor
      cellView.textField?.alignment = .right

    default:
      break
    }

    return cellView
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    if let tableView = notification.object as? NSTableView {
      selectedIndex = tableView.selectedRow
    }
  }

  private func categoryColor(for category: CodeCompletionProvider.CompletionItem.Category)
    -> NSColor
  {
    switch category {
    case .keyword:
      return .systemPurple
    case .primitive:
      return .systemBlue
    case .transformation:
      return .systemOrange
    case .csgOperation:
      return .systemGreen
    case .mathFunction:
      return .systemTeal
    case .listStringFunction:
      return .systemIndigo
    case .specialVariable:
      return .systemPink
    }
  }
}
