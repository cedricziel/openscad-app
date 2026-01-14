import AppKit
import SwiftUI

/// A popup view that displays code completion suggestions
final class CompletionPopupView: NSView {

  // MARK: - Properties

  private var items: [CompletionItem] = []
  private var selectedIndex: Int = 0
  private var onSelect: ((CompletionItem) -> Void)?
  private var onDismiss: (() -> Void)?

  private let scrollView: NSScrollView
  private let tableView: NSTableView
  private let documentationLabel: NSTextField

  private let rowHeight: CGFloat = 24
  private let maxVisibleRows = 8
  private let popupWidth: CGFloat = 350
  private let documentationHeight: CGFloat = 60

  // MARK: - Initialization

  override init(frame frameRect: NSRect) {
    scrollView = NSScrollView()
    tableView = NSTableView()
    documentationLabel = NSTextField(wrappingLabelWithString: "")

    super.init(frame: frameRect)

    setupView()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setupView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    layer?.borderColor = NSColor.separatorColor.cgColor
    layer?.borderWidth = 1
    layer?.cornerRadius = 6
    layer?.shadowColor = NSColor.black.cgColor
    layer?.shadowOpacity = 0.2
    layer?.shadowOffset = CGSize(width: 0, height: -2)
    layer?.shadowRadius = 4

    // Setup table view
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
    column.width = popupWidth - 20
    tableView.addTableColumn(column)
    tableView.headerView = nil
    tableView.rowHeight = rowHeight
    tableView.intercellSpacing = NSSize(width: 0, height: 2)
    tableView.backgroundColor = .clear
    tableView.delegate = self
    tableView.dataSource = self
    tableView.target = self
    tableView.doubleAction = #selector(rowDoubleClicked)
    tableView.selectionHighlightStyle = .regular

    // Setup scroll view
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.backgroundColor = .clear
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrollView)

    // Setup documentation label
    documentationLabel.font = NSFont.systemFont(ofSize: 11)
    documentationLabel.textColor = .secondaryLabelColor
    documentationLabel.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.95)
    documentationLabel.isEditable = false
    documentationLabel.isSelectable = false
    documentationLabel.isBordered = false
    documentationLabel.maximumNumberOfLines = 3
    documentationLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(documentationLabel)

    // Layout constraints
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

      documentationLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 4),
      documentationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      documentationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      documentationLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
      documentationLabel.heightAnchor.constraint(equalToConstant: documentationHeight),
    ])
  }

  // MARK: - Public Methods

  func show(
    items: [CompletionItem],
    at point: NSPoint,
    in parentView: NSView,
    onSelect: @escaping (CompletionItem) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    guard !items.isEmpty else {
      hide()
      return
    }

    self.items = items
    self.selectedIndex = 0
    self.onSelect = onSelect
    self.onDismiss = onDismiss

    tableView.reloadData()

    // Calculate frame
    let visibleRows = min(items.count, maxVisibleRows)
    let tableHeight = CGFloat(visibleRows) * (rowHeight + 2)
    let totalHeight = tableHeight + documentationHeight + 20

    // Position the popup below and to the right of the cursor
    var popupOrigin = point
    popupOrigin.y -= totalHeight + 4

    // Ensure popup stays within parent bounds
    let parentBounds = parentView.bounds
    if popupOrigin.x + popupWidth > parentBounds.maxX {
      popupOrigin.x = parentBounds.maxX - popupWidth - 8
    }
    if popupOrigin.y < parentBounds.minY {
      // Show above cursor instead
      popupOrigin.y = point.y + 20
    }

    frame = NSRect(x: popupOrigin.x, y: popupOrigin.y, width: popupWidth, height: totalHeight)

    if superview == nil {
      parentView.addSubview(self)
    }

    // Select first item
    selectRow(0)

    isHidden = false
  }

  func hide() {
    isHidden = true
    removeFromSuperview()
    onDismiss?()
  }

  func selectNext() {
    guard !items.isEmpty else { return }
    selectRow((selectedIndex + 1) % items.count)
  }

  func selectPrevious() {
    guard !items.isEmpty else { return }
    selectRow((selectedIndex - 1 + items.count) % items.count)
  }

  func confirmSelection() {
    guard selectedIndex < items.count else { return }
    let item = items[selectedIndex]
    hide()
    onSelect?(item)
  }

  var isVisible: Bool {
    return superview != nil && !isHidden
  }

  // MARK: - Private Methods

  private func selectRow(_ index: Int) {
    guard index >= 0, index < items.count else { return }

    selectedIndex = index
    tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    tableView.scrollRowToVisible(index)

    // Update documentation
    let item = items[index]
    documentationLabel.stringValue = item.documentation ?? ""
  }

  @objc private func rowDoubleClicked() {
    let clickedRow = tableView.clickedRow
    if clickedRow >= 0 && clickedRow < items.count {
      selectedIndex = clickedRow
      confirmSelection()
    }
  }
}

// MARK: - NSTableViewDataSource

extension CompletionPopupView: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    return items.count
  }
}

// MARK: - NSTableViewDelegate

extension CompletionPopupView: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
    -> NSView?
  {
    guard row < items.count else { return nil }

    let item = items[row]

    let cellView = NSTableCellView()
    cellView.identifier = NSUserInterfaceItemIdentifier("CompletionCell")

    // Create icon label
    let iconLabel = NSTextField(labelWithString: item.category.icon)
    iconLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
    iconLabel.textColor = item.category.color
    iconLabel.alignment = .center
    iconLabel.translatesAutoresizingMaskIntoConstraints = false

    // Create icon background
    let iconBackground = NSView()
    iconBackground.wantsLayer = true
    iconBackground.layer?.backgroundColor = item.category.color.withAlphaComponent(0.15).cgColor
    iconBackground.layer?.cornerRadius = 3
    iconBackground.translatesAutoresizingMaskIntoConstraints = false

    iconBackground.addSubview(iconLabel)

    // Create text label
    let textLabel = NSTextField(labelWithString: item.displayText)
    textLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textLabel.textColor = .textColor
    textLabel.lineBreakMode = .byTruncatingTail
    textLabel.translatesAutoresizingMaskIntoConstraints = false

    // Create category label
    let categoryLabel = NSTextField(labelWithString: item.category.rawValue)
    categoryLabel.font = NSFont.systemFont(ofSize: 10)
    categoryLabel.textColor = .tertiaryLabelColor
    categoryLabel.alignment = .right
    categoryLabel.translatesAutoresizingMaskIntoConstraints = false

    cellView.addSubview(iconBackground)
    cellView.addSubview(textLabel)
    cellView.addSubview(categoryLabel)

    NSLayoutConstraint.activate([
      iconBackground.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
      iconBackground.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
      iconBackground.widthAnchor.constraint(equalToConstant: 18),
      iconBackground.heightAnchor.constraint(equalToConstant: 18),

      iconLabel.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
      iconLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),

      textLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 8),
      textLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
      textLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: categoryLabel.leadingAnchor, constant: -8),

      categoryLabel.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
      categoryLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
      categoryLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 100),
    ])

    return cellView
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let newIndex = tableView.selectedRow
    if newIndex >= 0 && newIndex < items.count {
      selectedIndex = newIndex
      documentationLabel.stringValue = items[newIndex].documentation ?? ""
    }
  }
}
