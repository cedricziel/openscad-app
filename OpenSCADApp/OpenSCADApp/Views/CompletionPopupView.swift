import AppKit
import SwiftUI

/// A popup view that displays code completion suggestions
class CompletionPopupView: NSView {

  // MARK: - Properties

  private var completions: [CompletionItem] = []
  private var selectedIndex: Int = 0
  private var onSelect: ((CompletionItem) -> Void)?
  private var onDismiss: (() -> Void)?

  private let scrollView: NSScrollView
  private let tableView: NSTableView
  private let maxVisibleRows = 8
  private let rowHeight: CGFloat = 24

  // MARK: - Initialization

  override init(frame frameRect: NSRect) {
    scrollView = NSScrollView()
    tableView = NSTableView()

    super.init(frame: frameRect)

    setupView()
  }

  required init?(coder: NSCoder) {
    scrollView = NSScrollView()
    tableView = NSTableView()

    super.init(coder: coder)

    setupView()
  }

  // MARK: - Setup

  private func setupView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    layer?.borderColor = NSColor.separatorColor.cgColor
    layer?.borderWidth = 1
    layer?.cornerRadius = 6
    shadow = NSShadow()
    shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
    shadow?.shadowOffset = NSSize(width: 0, height: -2)
    shadow?.shadowBlurRadius = 8

    // Setup table view
    tableView.delegate = self
    tableView.dataSource = self
    tableView.headerView = nil
    tableView.rowHeight = rowHeight
    tableView.backgroundColor = .clear
    tableView.selectionHighlightStyle = .regular
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.focusRingType = .none

    // Add columns
    let iconColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
    iconColumn.width = 24
    iconColumn.minWidth = 24
    iconColumn.maxWidth = 24
    tableView.addTableColumn(iconColumn)

    let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
    textColumn.width = 200
    tableView.addTableColumn(textColumn)

    // Setup scroll view
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.backgroundColor = .clear
    scrollView.drawsBackground = false

    addSubview(scrollView)

    // Layout
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
    ])
  }

  // MARK: - Public Methods

  /// Updates the completion list
  func updateCompletions(
    _ completions: [CompletionItem],
    onSelect: @escaping (CompletionItem) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.completions = completions
    self.onSelect = onSelect
    self.onDismiss = onDismiss
    self.selectedIndex = 0

    tableView.reloadData()

    if !completions.isEmpty {
      tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    updateFrameSize()
  }

  /// Handles keyboard navigation
  func handleKeyDown(_ event: NSEvent) -> Bool {
    guard !completions.isEmpty else { return false }

    switch event.keyCode {
    case 125:  // Down arrow
      moveSelection(by: 1)
      return true
    case 126:  // Up arrow
      moveSelection(by: -1)
      return true
    case 36, 76:  // Return or Enter
      selectCurrentItem()
      return true
    case 53:  // Escape
      onDismiss?()
      return true
    case 48:  // Tab
      selectCurrentItem()
      return true
    default:
      return false
    }
  }

  // MARK: - Private Methods

  private func updateFrameSize() {
    let visibleRows = min(completions.count, maxVisibleRows)
    let contentHeight = CGFloat(visibleRows) * rowHeight + 8  // +8 for padding

    var newFrame = frame
    newFrame.size.height = contentHeight
    frame = newFrame
  }

  private func moveSelection(by delta: Int) {
    let newIndex = selectedIndex + delta

    if newIndex >= 0 && newIndex < completions.count {
      selectedIndex = newIndex
      tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
      tableView.scrollRowToVisible(selectedIndex)
    }
  }

  private func selectCurrentItem() {
    guard selectedIndex >= 0 && selectedIndex < completions.count else { return }
    onSelect?(completions[selectedIndex])
  }
}

// MARK: - NSTableViewDataSource

extension CompletionPopupView: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    completions.count
  }
}

// MARK: - NSTableViewDelegate

extension CompletionPopupView: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    guard row < completions.count else { return nil }

    let item = completions[row]

    if tableColumn?.identifier.rawValue == "icon" {
      let cellView = NSTextField(labelWithString: item.kind.icon)
      cellView.alignment = .center
      cellView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
      cellView.textColor = colorForKind(item.kind)
      return cellView
    } else {
      let cellView = NSTextField(labelWithString: item.label)
      cellView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
      cellView.lineBreakMode = .byTruncatingTail
      return cellView
    }
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    selectedIndex = tableView.selectedRow
  }

  func tableView(
    _ tableView: NSTableView,
    shouldSelectRow row: Int
  ) -> Bool {
    true
  }

  private func colorForKind(_ kind: CompletionItemKind) -> NSColor {
    switch kind {
    case .keyword: return .systemPurple
    case .function: return .systemBlue
    case .module: return .systemGreen
    case .variable: return .systemTeal
    case .snippet: return .systemOrange
    }
  }
}
