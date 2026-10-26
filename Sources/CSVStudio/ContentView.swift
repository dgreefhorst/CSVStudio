import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: CSVDocument
    let fileURL: URL?

    @Environment(\.undoManager) private var undoManager
    @StateObject private var editor = EditorState()
    @ViewState private var showFormat = false

    private var baseName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Naamloos"
    }

    /// SwiftUI meldt geopende documenten niet zelf aan bij het systeem; zonder
    /// deze aanroep blijft "Open recente bestanden" leeg.
    private func noteRecent(_ url: URL?) {
        guard let url else { return }
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    var body: some View {
        Group {
            if editor.mode == .table {
                tableMode
            } else {
                LinkedDataView(document: document, editor: editor, sourceName: baseName, onExport: exportTurtle)
            }
        }
        .frame(minWidth: 860, minHeight: 500)
        .toolbar { toolbarContent }
        .focusedSceneValue(\.csvActions, actions)
        .onAppear {
            editor.attach(binding: $document, undoManager: undoManager)
            noteRecent(fileURL)
        }
        .onChange(of: fileURL) { newURL in
            noteRecent(newURL)
        }
        .onChange(of: document.headers) { newHeaders in
            editor.syncMapping(headers: newHeaders)
        }
        .onChange(of: editor.mapping) { newMapping in
            MappingStore.save(newMapping, headers: document.headers)
        }
    }

    // MARK: Tabelweergave

    private var tableMode: some View {
        VStack(spacing: 0) {
            CSVGridView(document: document, filter: editor.filter, editor: editor)
            Divider()
            statusBar
        }
        .searchable(text: $editor.filter, placement: .toolbar, prompt: "Filter rijen")
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text("\(document.rows.count.formatted()) rijen · \(document.headers.count) kolommen")
            if !editor.selectedRows.isEmpty {
                Text("\(editor.selectedRows.count) geselecteerd")
            }
            Spacer()
            if let m = editor.statusMessage {
                Text(m)
            }
            Text("\(document.delimiter.label) · \(document.encoding.label)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: Werkbalk

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Weergave", selection: $editor.mode) {
                Text("Tabel").tag(EditorState.Mode.table)
                Text("Linked Data").tag(EditorState.Mode.linkedData)
            }
            .pickerStyle(.segmented)
            .frame(width: 230)
        }
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Button("Rij toevoegen", action: addRow)
                Button("Geselecteerde rij(en) verwijderen", action: deleteSelectedRows)
                    .disabled(editor.selectedRows.isEmpty)
                Divider()
                Button("Kolom toevoegen…", action: addColumn)
            } label: {
                Label("Rijen en kolommen", systemImage: "tablecells")
            }
            .disabled(editor.mode != .table)
            .help("Rijen en kolommen toevoegen of verwijderen")

            Button {
                showFormat.toggle()
            } label: {
                Label("Bestandsopmaak", systemImage: "gearshape")
            }
            .help("Scheidingsteken, tekenset en kopregel")
            .popover(isPresented: $showFormat, arrowEdge: .bottom) { formatPopover }

            Menu {
                Button("Excel-werkmap (.xlsx)…", action: exportExcel)
                Button("Openen in Excel", action: openInExcel)
                Divider()
                Button("Linked Data (Turtle, .ttl)…", action: exportTurtle)
            } label: {
                Label("Exporteer", systemImage: "square.and.arrow.up")
            }
            .help("Exporteren naar Excel of Turtle")
        }
    }

    private var formatPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bestandsopmaak").font(.headline)

            Toggle("Eerste rij is kopregel", isOn: Binding(
                get: { document.hasHeader },
                set: { v in editor.commit("Kopregel") { $0.setHasHeader(v) } }
            ))

            Picker("Scheidingsteken", selection: Binding(
                get: { document.delimiter },
                set: { v in editor.commit("Scheidingsteken") { $0.delimiter = v } }
            )) {
                ForEach(CSVDelimiter.allCases) { Text($0.label).tag($0) }
            }

            Picker("Tekenset", selection: Binding(
                get: { document.encoding },
                set: { v in editor.commit("Tekenset") { $0.encoding = v } }
            )) {
                ForEach(CSVEncoding.allCases) { Text($0.label).tag($0) }
            }

            Picker("Regeleinde", selection: Binding(
                get: { document.crlf },
                set: { v in editor.commit("Regeleinde") { $0.crlf = v } }
            )) {
                Text("macOS / Unix (LF)").tag(false)
                Text("Windows (CRLF)").tag(true)
            }

            Text("Deze instellingen gelden bij het opslaan. Excel in Nederland verwacht vaak puntkomma en UTF-8 met BOM.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 340)
    }

    // MARK: Acties voor menu en werkbalk

    private var actions: CSVActions {
        CSVActions(
            exportExcel: exportExcel,
            openInExcel: openInExcel,
            exportTurtle: exportTurtle,
            showTable: { editor.mode = .table },
            showLinkedData: { editor.mode = .linkedData },
            addRow: addRow,
            deleteRows: deleteSelectedRows,
            addColumn: addColumn
        )
    }

    private func addRow() {
        editor.mode = .table
        let at = (editor.selectedRows.max().map { $0 + 1 }) ?? document.rows.count
        editor.pendingSelection = [at]
        editor.commit("Rij toevoegen") { $0.insertRow(at: at) }
    }

    private func deleteSelectedRows() {
        let rows = editor.selectedRows
        guard !rows.isEmpty else { return }
        editor.commit("Rijen verwijderen") { $0.deleteRows(rows) }
    }

    private func addColumn() {
        editor.mode = .table
        guard let name = Dialogs.promptText(title: "Kolom toevoegen", message: "Naam van de nieuwe kolom:", initial: "Nieuwe kolom") else { return }
        let n = name.trimmed.isEmpty ? CSVDocument.defaultHeader(document.headers.count) : name.trimmed
        editor.commit("Kolom toevoegen") { $0.insertColumn(at: $0.headers.count, name: n) }
    }

    // MARK: Excel

    private func buildXLSX() -> XLSXWriter.Output {
        XLSXWriter.make(headers: document.headers, rows: document.rows, includeHeader: document.hasHeader, sheetName: baseName)
    }

    private func exportExcel() {
        guard let url = Dialogs.askSaveURL(ext: "xlsx", name: baseName, title: "Exporteer als Excel-werkmap") else { return }
        let doc = document
        let name = baseName
        editor.setStatus("Excel-bestand maken…")
        DispatchQueue.global(qos: .userInitiated).async {
            let out = XLSXWriter.make(headers: doc.headers, rows: doc.rows, includeHeader: doc.hasHeader, sheetName: name)
            do {
                try out.data.write(to: url, options: .atomic)
                DispatchQueue.main.async {
                    var msg = "Excel-werkmap opgeslagen: \(url.lastPathComponent)"
                    if out.truncated { msg += " (let op: ingekort tot de limieten van Excel)" }
                    editor.setStatus(msg)
                }
            } catch {
                DispatchQueue.main.async { Dialogs.showError(error) }
            }
        }
    }

    private func openInExcel() {
        let out = buildXLSX()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = dir.appendingPathComponent(baseName + ".xlsx")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try out.data.write(to: url, options: .atomic)
        } catch {
            Dialogs.showError(error)
            return
        }
        if let excel = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Excel") {
            NSWorkspace.shared.open([url], withApplicationAt: excel, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
            editor.setStatus("Excel niet gevonden; geopend met de standaardapp voor .xlsx.")
        }
    }

    // MARK: Turtle

    private func exportTurtle() {
        guard let url = Dialogs.askSaveURL(ext: "ttl", conformingTo: .plainText, name: baseName, title: "Exporteer als Turtle") else { return }
        let mapping = editor.mapping
        let headers = document.headers
        let rows = document.rows
        let name = fileURL?.lastPathComponent ?? baseName
        editor.setStatus("Turtle genereren…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = TurtleWriter(mapping: mapping, headers: headers)
                .generate(rows: rows, range: 0..<rows.count, sourceName: name)
            do {
                try result.text.write(to: url, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    var msg = "Turtle opgeslagen: \(result.subjectCount) resources, \(result.tripleCount) triples"
                    if !result.warnings.isEmpty { msg += " (\(result.warnings.count) waarschuwing(en), zie voorbeeld)" }
                    editor.setStatus(msg)
                }
            } catch {
                DispatchQueue.main.async { Dialogs.showError(error) }
            }
        }
    }
}
