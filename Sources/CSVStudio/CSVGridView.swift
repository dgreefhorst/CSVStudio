import SwiftUI
import AppKit

// MARK: - Kopregel met dubbelklik-hernoemen en contextmenu

final class GridHeaderView: NSTableHeaderView {
    var onDoubleClick: ((Int) -> Void)?
    private(set) var contextColumn = -1

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let p = convert(event.locationInWindow, from: nil)
            let col = column(at: p)
            if col >= 0 {
                onDoubleClick?(col)
                return
            }
        }
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        contextColumn = column(at: p)
        return super.menu(for: event)
    }
}

// MARK: - Tabel met kopiëren/plakken en toetsenbord

final class GridTableView: NSTableView {
    var activeColumn = -1
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    var onDelete: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        activeColumn = column(at: p)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / Enter: bewerk de laatst aangeklikte cel
            if selectedRowIndexes.count == 1, activeColumn >= 1, let row = selectedRowIndexes.first {
                editColumn(activeColumn, row: row, with: nil, select: true)
                return
            }
        case 51, 117: // Backspace / Delete: verwijder geselecteerde rijen
            if !selectedRowIndexes.isEmpty {
                onDelete?()
                return
            }
        default:
            break
        }
        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) { onCopy?() }
    @objc func paste(_ sender: Any?) { onPaste?() }
}

// MARK: - SwiftUI-brug

struct CSVGridView: NSViewRepresentable {
    let document: CSVDocument
    let filter: String
    let editor: EditorState

    func makeCoordinator() -> GridCoordinator {
        GridCoordinator(editor: editor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let c = context.coordinator
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let tv = GridTableView()
        tv.usesAlternatingRowBackgroundColors = true
        tv.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        tv.allowsMultipleSelection = true
        tv.allowsColumnReordering = false
        tv.allowsColumnSelection = false
        tv.allowsColumnResizing = true
        tv.columnAutoresizingStyle = .noColumnAutoresizing
        tv.rowSizeStyle = .custom
        tv.rowHeight = 22
        tv.intercellSpacing = NSSize(width: 4, height: 1)

        let header = GridHeaderView()
        tv.headerView = header
        header.menu = c.headerMenu
        header.onDoubleClick = { [weak c] col in c?.headerDoubleClicked(tableColumn: col) }
        tv.menu = c.rowMenu

        tv.onCopy = { [weak c] in c?.copySelection() }
        tv.onPaste = { [weak c] in c?.pasteAtSelection() }
        tv.onDelete = { [weak c] in c?.deleteSelectedRows() }

        tv.dataSource = c
        tv.delegate = c
        c.tableView = tv
        c.headerView = header
        scroll.documentView = tv

        c.update(document: document, filter: filter)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.update(document: document, filter: filter)
    }
}

// MARK: - Coördinator

final class GridCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    let editor: EditorState
    weak var tableView: GridTableView?
    weak var headerView: GridHeaderView?

    private var doc = CSVDocument()
    private var visible: [Int] = []
    private var lastRevision = -1
    private var lastFilter = "\u{0}"
    private var lastHeaders: [String] = []
    private var widths: [String: CGFloat] = [:]
    private var suppressSelection = false

    let rowMenu = NSMenu()
    let headerMenu = NSMenu()

    init(editor: EditorState) {
        self.editor = editor
        super.init()
        buildMenus()
    }

    // MARK: Menu's

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    private func buildMenus() {
        rowMenu.addItem(item("Rij erboven invoegen", #selector(menuInsertAbove)))
        rowMenu.addItem(item("Rij eronder invoegen", #selector(menuInsertBelow)))
        rowMenu.addItem(item("Rij(en) dupliceren", #selector(menuDuplicate)))
        rowMenu.addItem(item("Rij(en) verwijderen", #selector(menuDeleteRows)))
        rowMenu.addItem(.separator())
        rowMenu.addItem(item("Kopieer rij(en)", #selector(menuCopyRows)))
        rowMenu.addItem(item("Plak", #selector(menuPaste)))

        headerMenu.addItem(item("Kolomnaam wijzigen…", #selector(menuRenameColumn)))
        headerMenu.addItem(item("Kolom links invoegen…", #selector(menuInsertColumnLeft)))
        headerMenu.addItem(item("Kolom rechts invoegen…", #selector(menuInsertColumnRight)))
        headerMenu.addItem(item("Kolom verwijderen", #selector(menuDeleteColumn)))
        headerMenu.addItem(.separator())
        headerMenu.addItem(item("Sorteer A → Z", #selector(menuSortAscending)))
        headerMenu.addItem(item("Sorteer Z → A", #selector(menuSortDescending)))
        headerMenu.addItem(.separator())
        headerMenu.addItem(item("Kolombreedte aanpassen", #selector(menuFitWidth)))
    }

    // MARK: Bijwerken vanuit SwiftUI

    func update(document newDoc: CSVDocument, filter newFilter: String) {
        guard let tv = tableView else { return }
        let pending = editor.pendingSelection
        if newDoc.revision == lastRevision && newFilter == lastFilter && pending == nil { return }

        let oldSelection = tv.selectedRowIndexes.compactMap { $0 < visible.count ? visible[$0] : nil }
        let headersChanged = newDoc.headers != lastHeaders || tv.tableColumns.isEmpty

        doc = newDoc
        lastRevision = newDoc.revision
        lastFilter = newFilter
        recomputeVisible()

        if headersChanged {
            rebuildColumns()
            lastHeaders = newDoc.headers
            tv.activeColumn = -1
        }
        tv.reloadData()

        editor.pendingSelection = nil
        let target = pending ?? oldSelection
        let positions = target.compactMap { position(of: $0) }
        if !positions.isEmpty {
            suppressSelection = true
            tv.selectRowIndexes(IndexSet(positions), byExtendingSelection: false)
            suppressSelection = false
            if pending != nil, let first = positions.first { tv.scrollRowToVisible(first) }
        }
        syncSelectionToEditor()
    }

    private func recomputeVisible() {
        let f = lastFilter.trimmed
        if f.isEmpty {
            visible = Array(0..<doc.rows.count)
        } else {
            var out: [Int] = []
            for (i, row) in doc.rows.enumerated() {
                for cell in row where cell.range(of: f, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    out.append(i)
                    break
                }
            }
            visible = out
        }
    }

    /// Positie van een bronrij in de (oplopend gesorteerde) zichtbare lijst.
    private func position(of source: Int) -> Int? {
        var lo = 0
        var hi = visible.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if visible[mid] < source { lo = mid + 1 } else { hi = mid }
        }
        return lo < visible.count && visible[lo] == source ? lo : nil
    }

    private func syncSelectionToEditor() {
        guard let tv = tableView else { return }
        let src = tv.selectedRowIndexes.compactMap { $0 < visible.count ? visible[$0] : nil }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.editor.selectedRows != src { self.editor.selectedRows = src }
        }
    }

    // MARK: Kolommen

    private func autoWidth(_ col: Int) -> CGFloat {
        var maxLen = col < doc.headers.count ? doc.headers[col].count + 3 : 8
        for row in doc.rows.prefix(200) where col < row.count {
            maxLen = max(maxLen, row[col].count)
        }
        return min(max(CGFloat(maxLen) * 7.2 + 24, 70), 320)
    }

    private func rebuildColumns() {
        guard let tv = tableView else { return }
        for col in tv.tableColumns where col.identifier.rawValue != "rownum" {
            widths[col.title] = col.width
        }
        for col in tv.tableColumns { tv.removeTableColumn(col) }

        let rn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rownum"))
        rn.title = "#"
        rn.width = 52
        rn.minWidth = 36
        rn.isEditable = false
        tv.addTableColumn(rn)

        for (i, h) in doc.headers.enumerated() {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(i)"))
            c.title = h
            c.minWidth = 40
            c.maxWidth = 3000
            c.width = widths[h] ?? autoWidth(i)
            tv.addTableColumn(c)
        }
    }

    private func dataColumn(forTableColumnIndex idx: Int) -> Int? {
        (idx >= 1 && idx <= doc.headers.count) ? idx - 1 : nil
    }

    // MARK: NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { visible.count }

    private func makeCell(identifier: String, editable: Bool) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = NSUserInterfaceItemIdentifier(identifier)
        let tf = NSTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.isEditable = editable
        tf.isSelectable = editable
        tf.lineBreakMode = .byTruncatingTail
        tf.maximumNumberOfLines = 1
        tf.cell?.usesSingleLineMode = true
        tf.cell?.isScrollable = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        if editable {
            tf.font = NSFont.systemFont(ofSize: 12)
            tf.delegate = self
        } else {
            tf.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            tf.textColor = .secondaryLabelColor
            tf.alignment = .right
        }
        cell.addSubview(tf)
        cell.textField = tf
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, row < visible.count else { return nil }
        let src = visible[row]
        if column.identifier.rawValue == "rownum" {
            let id = "rowcell"
            let cell = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: self) as? NSTableCellView)
                ?? makeCell(identifier: id, editable: false)
            cell.textField?.stringValue = String(src + 1)
            return cell
        }
        guard let ci = Int(column.identifier.rawValue.dropFirst()), src < doc.rows.count, ci < doc.rows[src].count else { return nil }
        let id = "datacell"
        let cell = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: self) as? NSTableCellView)
            ?? makeCell(identifier: id, editable: true)
        cell.textField?.stringValue = doc.rows[src][ci]
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if suppressSelection { return }
        syncSelectionToEditor()
    }

    // MARK: Cel bewerken

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let tf = obj.object as? NSTextField, let tv = tableView else { return }
        let row = tv.row(for: tf)
        let colIdx = tv.column(for: tf)
        guard row >= 0, row < visible.count, let ci = dataColumn(forTableColumnIndex: colIdx) else { return }
        let src = visible[row]
        guard src < doc.rows.count, ci < doc.rows[src].count else { return }

        let newValue = tf.stringValue
        if doc.rows[src][ci] != newValue {
            editor.commit("Cel bewerken") { $0.setCell(row: src, col: ci, value: newValue) }
            doc = editor.currentDoc
            lastRevision = doc.revision
        }

        // Tab / Shift-Tab / Return: door naar de volgende cel
        let raw = (obj.userInfo?["NSTextMovement"] as? Int) ?? 0
        guard let movement = NSTextMovement(rawValue: raw) else { return }
        var nextRow = row
        var nextCol = colIdx
        let lastCol = doc.headers.count
        switch movement {
        case .tab:
            if colIdx < lastCol {
                nextCol = colIdx + 1
            } else if row + 1 < visible.count {
                nextRow = row + 1
                nextCol = 1
            } else {
                return
            }
        case .backtab:
            if colIdx > 1 {
                nextCol = colIdx - 1
            } else if row > 0 {
                nextRow = row - 1
                nextCol = lastCol
            } else {
                return
            }
        case .return:
            if row + 1 < visible.count { nextRow = row + 1 } else { return }
        default:
            return
        }
        DispatchQueue.main.async {
            tv.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            tv.scrollRowToVisible(nextRow)
            tv.activeColumn = nextCol
            tv.editColumn(nextCol, row: nextRow, with: nil, select: true)
        }
    }

    // MARK: Kopiëren en plakken

    func copySelection() {
        guard let tv = tableView else { return }
        let sel = Array(tv.selectedRowIndexes)
        guard !sel.isEmpty else {
            NSSound.beep()
            return
        }
        if sel.count == 1, let ci = dataColumn(forTableColumnIndex: tv.activeColumn), sel[0] < visible.count {
            let src = visible[sel[0]]
            if src < doc.rows.count, ci < doc.rows[src].count {
                putOnPasteboard(doc.rows[src][ci])
                return
            }
        }
        copyRows(sel.compactMap { $0 < visible.count ? visible[$0] : nil })
    }

    private func copyRows(_ sourceRows: [Int]) {
        var lines: [String] = []
        for src in sourceRows where src < doc.rows.count {
            lines.append(doc.rows[src].map { CSVDocument.quote($0, delimiter: "\t") }.joined(separator: "\t"))
        }
        putOnPasteboard(lines.joined(separator: "\n"))
    }

    private func putOnPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func pasteAtSelection() {
        guard let tv = tableView, let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        var block = CSVDocument.parseRecords(Array(text.utf8), delimiter: 0x09)
        if block.isEmpty { block = [[text]] }
        let width = block.reduce(0) { max($0, $1.count) }
        var row = doc.rows.count
        if let first = tv.selectedRowIndexes.first, first < visible.count { row = visible[first] }
        var col = 0
        if width < doc.headers.count, let c = dataColumn(forTableColumnIndex: tv.activeColumn) { col = c }
        editor.pendingSelection = [row]
        editor.commit("Plakken") { $0.pasteBlock(block, atRow: row, col: col) }
    }

    func deleteSelectedRows() {
        guard let tv = tableView else { return }
        let rows = tv.selectedRowIndexes.compactMap { $0 < visible.count ? visible[$0] : nil }
        guard !rows.isEmpty else { return }
        editor.commit("Rijen verwijderen") { $0.deleteRows(rows) }
    }

    // MARK: Contextmenu rijen

    private func targetRows() -> [Int] {
        guard let tv = tableView else { return [] }
        var idx = tv.selectedRowIndexes
        let clicked = tv.clickedRow
        if clicked >= 0 && !idx.contains(clicked) { idx = IndexSet(integer: clicked) }
        return idx.compactMap { $0 < visible.count ? visible[$0] : nil }
    }

    @objc private func menuInsertAbove() {
        let at = targetRows().min() ?? doc.rows.count
        editor.pendingSelection = [at]
        editor.commit("Rij invoegen") { $0.insertRow(at: at) }
    }

    @objc private func menuInsertBelow() {
        let at = (targetRows().max().map { $0 + 1 }) ?? doc.rows.count
        editor.pendingSelection = [at]
        editor.commit("Rij invoegen") { $0.insertRow(at: at) }
    }

    @objc private func menuDuplicate() {
        let rows = targetRows()
        guard let last = rows.max() else { return }
        editor.pendingSelection = [last + 1]
        editor.commit("Rijen dupliceren") { $0.duplicateRows(rows) }
    }

    @objc private func menuDeleteRows() {
        let rows = targetRows()
        guard !rows.isEmpty else { return }
        editor.commit("Rijen verwijderen") { $0.deleteRows(rows) }
    }

    @objc private func menuCopyRows() {
        copyRows(targetRows())
    }

    @objc private func menuPaste() {
        pasteAtSelection()
    }

    // MARK: Contextmenu kolommen

    private var menuColumn: Int? {
        guard let h = headerView else { return nil }
        let idx = h.contextColumn - 1
        return (0..<doc.headers.count).contains(idx) ? idx : nil
    }

    func headerDoubleClicked(tableColumn idx: Int) {
        if let c = dataColumn(forTableColumnIndex: idx) { renameColumn(at: c) }
    }

    private func renameColumn(at c: Int) {
        guard c < doc.headers.count else { return }
        guard let name = Dialogs.promptText(title: "Kolomnaam wijzigen", message: "Nieuwe naam voor deze kolom:", initial: doc.headers[c]) else { return }
        let n = name.trimmed
        guard !n.isEmpty, n != doc.headers[c] else { return }
        editor.commit("Kolomnaam wijzigen") { $0.renameColumn(c, to: n) }
    }

    private func insertColumn(at index: Int) {
        guard let name = Dialogs.promptText(title: "Kolom invoegen", message: "Naam van de nieuwe kolom:", initial: "Nieuwe kolom") else { return }
        let n = name.trimmed.isEmpty ? CSVDocument.defaultHeader(index) : name.trimmed
        editor.commit("Kolom invoegen") { $0.insertColumn(at: index, name: n) }
    }

    @objc private func menuRenameColumn() {
        if let c = menuColumn { renameColumn(at: c) }
    }

    @objc private func menuInsertColumnLeft() {
        if let c = menuColumn { insertColumn(at: c) }
    }

    @objc private func menuInsertColumnRight() {
        if let c = menuColumn { insertColumn(at: c + 1) }
    }

    @objc private func menuDeleteColumn() {
        guard let c = menuColumn else { return }
        if doc.headers.count <= 1 {
            NSSound.beep()
            return
        }
        editor.commit("Kolom verwijderen") { $0.deleteColumn(at: c) }
    }

    @objc private func menuSortAscending() {
        if let c = menuColumn { editor.commit("Sorteren") { $0.sortRows(byColumn: c, ascending: true) } }
    }

    @objc private func menuSortDescending() {
        if let c = menuColumn { editor.commit("Sorteren") { $0.sortRows(byColumn: c, ascending: false) } }
    }

    @objc private func menuFitWidth() {
        guard let c = menuColumn, let tv = tableView, c + 1 < tv.tableColumns.count else { return }
        tv.tableColumns[c + 1].width = autoWidth(c)
    }
}
