import AppKit
import SwiftUI

/// AppKit table for the menu-bar panel.
///
/// SwiftUI `List` / `scrollTo` will not do Spotlight-style arrow movement
/// while a search field stays focused. This table never becomes first
/// responder; `PanelKeyRouter` updates selection, and we only call
/// `scrollRowToVisible` when the focused row is clipped.
struct PanelSkillTable: NSViewRepresentable {
    var rows: [PanelTableRow]
    var selectedIDs: Set<Skill.ID>
    var focusID: Skill.ID?
    var model: AppModel

    func makeCoordinator() -> PanelSkillTableCoordinator {
        PanelSkillTableCoordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)

        let table = PanelNSTableView()
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.headerView = nil
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = false
        table.allowsTypeSelect = false
        table.usesAlternatingRowBackgroundColors = false
        table.usesAutomaticRowHeights = false
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.rowSizeStyle = .custom
        table.style = .inset
        table.focusRingType = .none
        table.floatsGroupRows = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("skill"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)

        scroll.documentView = table
        context.coordinator.tableView = table
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.model = model
        let rowsChanged = coordinator.rows != rows
        coordinator.rows = rows

        guard let table = coordinator.tableView else { return }
        if rowsChanged {
            table.reloadData()
            table.layoutSubtreeIfNeeded()
        }
        coordinator.syncSelection(
            selectedIDs: selectedIDs,
            focusID: focusID,
            forceScroll: rowsChanged
        )
    }
}

@MainActor
final class PanelSkillTableCoordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
    var model: AppModel
    var rows: [PanelTableRow] = []
    weak var tableView: NSTableView?

    private var isSyncing = false

    init(model: AppModel) {
        self.model = model
    }

    func syncSelection(selectedIDs: Set<Skill.ID>, focusID: Skill.ID?, forceScroll: Bool) {
        guard let table = tableView else { return }

        var indexes = IndexSet()
        var focusRow: Int?
        for (index, row) in rows.enumerated() {
            guard let id = row.skillID, selectedIDs.contains(id) else { continue }
            indexes.insert(index)
            if id == focusID {
                focusRow = index
            }
        }

        if table.selectedRowIndexes != indexes {
            isSyncing = true
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            isSyncing = false
        }

        let target = focusRow ?? indexes.first
        guard let target else { return }
        let rowRect = table.rect(ofRow: target)
        let needsScroll = forceScroll || !table.visibleRect.contains(rowRect)
        guard needsScroll else { return }
        table.scrollRowToVisible(target)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows.indices.contains(row) && rows[row].skillID != nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard rows.indices.contains(row) else { return PanelSkillTableMetrics.skillHeight }
        switch rows[row] {
        case .header:
            return PanelSkillTableMetrics.headerHeight
        case .skill:
            return PanelSkillTableMetrics.skillHeight
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("panel-row")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: nil) as? PanelSkillHostingCell)
            ?? PanelSkillHostingCell()
        cell.identifier = identifier

        switch rows[row] {
        case .header(_, let title, let count):
            cell.setContent(PanelSectionHeader(title: title, count: count))
        case .skill(let entry):
            cell.setContent(
                PanelSkillRow(entry: entry)
                    .environment(model)
            )
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSyncing, let table = tableView else { return }
        var ids = Set<Skill.ID>()
        for index in table.selectedRowIndexes {
            guard rows.indices.contains(index), let id = rows[index].skillID else { continue }
            ids.insert(id)
        }
        model.applyPanelListSelection(ids)
    }
}

private enum PanelSkillTableMetrics {
    static let headerHeight: CGFloat = 22
    static let skillHeight: CGFloat = 58
}

private final class PanelNSTableView: NSTableView {
    override var acceptsFirstResponder: Bool { false }

    override func becomeFirstResponder() -> Bool {
        false
    }

    override func keyDown(with event: NSEvent) {}

    override func interpretKeyEvents(_ eventArray: [NSEvent]) {}
}

private final class PanelSkillHostingCell: NSTableCellView {
    private let hosting = NSHostingView(rootView: AnyView(EmptyView()))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            hosting.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ view: some View) {
        hosting.rootView = AnyView(view)
    }
}
