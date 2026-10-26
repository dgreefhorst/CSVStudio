import SwiftUI
import AppKit

/// Toestand per documentvenster: weergave, selectie, filter, Linked Data-koppeling en ongedaan maken.
final class EditorState: ObservableObject {
    enum Mode { case table, linkedData }

    @Published var mode: Mode = .table
    @Published var filter = ""
    @Published var selectedRows: [Int] = []
    @Published var statusMessage: String?
    @Published var mapping = LDMapping()

    /// Rijen (bronindex) die na de volgende herlaadbeurt geselecteerd moeten worden.
    var pendingSelection: [Int]?
    var undoManager: UndoManager?

    private var getDoc: () -> CSVDocument = { CSVDocument() }
    private var setDoc: (CSVDocument) -> Void = { _ in }
    private var attached = false

    func attach(binding: Binding<CSVDocument>, undoManager: UndoManager?) {
        self.undoManager = undoManager
        getDoc = { binding.wrappedValue }
        setDoc = { binding.wrappedValue = $0 }
        if !attached {
            attached = true
            loadMapping(headers: binding.wrappedValue.headers)
        }
    }

    var currentDoc: CSVDocument { getDoc() }

    // MARK: Wijzigen met ongedaan maken

    func commit(_ name: String, _ change: (inout CSVDocument) -> Void) {
        let old = getDoc()
        var new = old
        change(&new)
        new.touch()
        setDoc(new)
        registerUndo(old, name)
    }

    private func registerUndo(_ snapshot: CSVDocument, _ name: String) {
        guard let um = undoManager else { return }
        um.registerUndo(withTarget: self) { target in target.restore(snapshot, name) }
        um.setActionName(name)
    }

    private func restore(_ snapshot: CSVDocument, _ name: String) {
        let current = getDoc()
        setDoc(snapshot)
        guard let um = undoManager else { return }
        um.registerUndo(withTarget: self) { target in target.restore(current, name) }
        um.setActionName(name)
    }

    // MARK: Koppeling

    func loadMapping(headers: [String]) {
        var m = MappingStore.load(headers: headers) ?? MappingStore.fresh(headers: headers)
        m.syncColumns(with: headers)
        mapping = m
    }

    func syncMapping(headers: [String]) {
        var m = mapping
        m.syncColumns(with: headers)
        if m != mapping { mapping = m }
    }

    // MARK: Statusbericht

    func setStatus(_ text: String) {
        statusMessage = text
        let current = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.statusMessage == current { self?.statusMessage = nil }
        }
    }
}

/// Acties die vanuit het menu naar het actieve venster gaan.
struct CSVActions {
    var exportExcel: () -> Void
    var openInExcel: () -> Void
    var exportTurtle: () -> Void
    var showTable: () -> Void
    var showLinkedData: () -> Void
    var addRow: () -> Void
    var deleteRows: () -> Void
    var addColumn: () -> Void
}

struct CSVActionsKey: FocusedValueKey {
    typealias Value = CSVActions
}

extension FocusedValues {
    var csvActions: CSVActions? {
        get { self[CSVActionsKey.self] }
        set { self[CSVActionsKey.self] = newValue }
    }
}
