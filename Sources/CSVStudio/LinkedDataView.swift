import SwiftUI
import AppKit

// MARK: - Keuzelijst met vocabulaires (predicaten of klassen)

struct VocabPicker: View {
    enum Kind { case properties, classes }

    let kind: Kind
    let onPick: (String) -> Void
    @ViewState private var query = ""

    private struct Group: Identifiable {
        let vocab: Vocabulary
        let items: [String]
        var id: String { vocab.prefix }
    }

    private var groups: [Group] {
        let q = query.trimmed.lowercased()
        return Vocabularies.all.compactMap { v in
            let locals = kind == .properties ? v.properties : v.classes
            let matchesVocab = !q.isEmpty && (v.prefix == q || v.title.lowercased().contains(q))
            let items = locals.map { v.prefix + ":" + $0 }.filter { q.isEmpty || matchesVocab || $0.lowercased().contains(q) }
            return items.isEmpty ? nil : Group(vocab: v, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Zoek (bijv. naam, label of foaf)", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List {
                ForEach(groups) { g in
                    Section(g.vocab.title + " (" + g.vocab.prefix + ":)") {
                        ForEach(g.items, id: \.self) { item in
                            Button {
                                onPick(item)
                            } label: {
                                Text(item).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 330, height: 420)
    }
}

// MARK: - Eigen voorvoegsels

struct PrefixSheet: View {
    @Binding var prefixes: [CustomPrefix]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eigen voorvoegsels (prefixen)").font(.headline)
            Text("Voeg vocabulaires toe die niet in de lijst staan, bijvoorbeeld ex → https://example.org/vocab#. Typ daarna bij een kolom het predicaat, bijvoorbeeld ex:naam.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            List {
                ForEach($prefixes) { $p in
                    HStack {
                        TextField("prefix", text: $p.prefix).frame(width: 100)
                        TextField("namespace-URI", text: $p.namespace)
                        Button(role: .destructive) {
                            let id = p.id
                            prefixes.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 120)
            DisclosureGroup("Ingebouwde voorvoegsels") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Vocabularies.all) { v in
                            Text("\(v.prefix):  \(v.namespace)")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 130)
            }
            HStack {
                Button("Toevoegen") { prefixes.append(CustomPrefix()) }
                Spacer()
                Button("Gereed") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 580, height: 470)
    }
}

// MARK: - Linked Data-weergave

struct LinkedDataView: View {
    let document: CSVDocument
    @ObservedObject var editor: EditorState
    let sourceName: String
    let onExport: () -> Void

    private enum PickerTarget: Hashable {
        case predicate(UUID)
        case classes
    }

    @ViewState private var previewRows = 25
    @ViewState private var pickerTarget: PickerTarget?
    @ViewState private var showPrefixes = false

    var body: some View {
        let result = TurtleWriter(mapping: editor.mapping, headers: document.headers)
            .generate(rows: document.rows, range: 0..<min(previewRows, document.rows.count), sourceName: sourceName)
        return HSplitView {
            mappingPane
                .frame(minWidth: 600, idealWidth: 680)
            previewPane(result)
                .frame(minWidth: 380)
        }
        .onAppear { editor.syncMapping(headers: document.headers) }
        .sheet(isPresented: $showPrefixes) {
            PrefixSheet(prefixes: $editor.mapping.customPrefixes)
        }
    }

    // MARK: Koppelingen

    private func popoverBinding(_ target: PickerTarget) -> Binding<Bool> {
        Binding(
            get: { pickerTarget == target },
            set: { if !$0 && pickerTarget == target { pickerTarget = nil } }
        )
    }

    private var resolver: TermResolver { TermResolver(mapping: editor.mapping) }

    private var mappingPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Resource") {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Text("Basis-URI")
                            TextField("https://example.org/id/", text: $editor.mapping.baseURI)
                                .textFieldStyle(.roundedBorder)
                        }
                        GridRow {
                            Text("Klasse van de rijen")
                            HStack {
                                TextField("bijv. foaf:Person (meerdere met komma)", text: $editor.mapping.classes)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    pickerTarget = .classes
                                } label: {
                                    Image(systemName: "list.bullet.rectangle")
                                }
                                .help("Kies een klasse uit bekende vocabulaires")
                                .popover(isPresented: popoverBinding(.classes)) {
                                    VocabPicker(kind: .classes) { pick in
                                        let current = editor.mapping.classes.trimmed
                                        editor.mapping.classes = current.isEmpty ? pick : current + ", " + pick
                                        pickerTarget = nil
                                    }
                                }
                            }
                        }
                        GridRow {
                            Text("Subject-URI")
                            HStack {
                                TextField("{kolomnaam} of {#} voor rijnummer", text: $editor.mapping.subjectTemplate)
                                    .textFieldStyle(.roundedBorder)
                                Menu {
                                    Button("{#}  rijnummer") { editor.mapping.subjectTemplate += "{#}" }
                                    Divider()
                                    ForEach(document.headers.indices, id: \.self) { i in
                                        Button("{\(document.headers[i])}") { editor.mapping.subjectTemplate += "{\(document.headers[i])}" }
                                    }
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .help("Voeg een kolom in het sjabloon in")
                            }
                        }
                        GridRow {
                            Text("Standaardtaal")
                            HStack {
                                TextField("nl", text: $editor.mapping.defaultLanguage)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Text("voor kolommen van het type ‘Tekst met taal’")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(6)
                }

                GroupBox("Kolommen → predicaten") {
                    VStack(alignment: .leading, spacing: 8) {
                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                            GridRow {
                                Text("")
                                Text("Kolom")
                                Text("Predicaat")
                                Text("Type")
                                Text("Taal")
                                Text("Scheiding")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            ForEach($editor.mapping.columns) { $col in
                                GridRow {
                                    Toggle("", isOn: $col.enabled).labelsHidden()
                                    Text(col.header)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(width: 130, alignment: .leading)
                                        .help(col.header)
                                    HStack(spacing: 4) {
                                        TextField("prefix:term", text: Binding(
                                            get: { col.predicate },
                                            set: { v in
                                                col.predicate = v
                                                if !v.trimmed.isEmpty { col.enabled = true }
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .foregroundColor(col.predicate.trimmed.isEmpty || resolver.isResolvable(col.predicate) ? .primary : .red)
                                        .frame(minWidth: 150)
                                        Button {
                                            pickerTarget = .predicate(col.id)
                                        } label: {
                                            Image(systemName: "list.bullet.rectangle")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Kies een predicaat uit bekende vocabulaires")
                                        .popover(isPresented: popoverBinding(.predicate(col.id))) {
                                            VocabPicker(kind: .properties) { pick in
                                                col.predicate = pick
                                                col.enabled = true
                                                pickerTarget = nil
                                            }
                                        }
                                    }
                                    Picker("", selection: $col.kind) {
                                        ForEach(ValueKind.allCases) { Text($0.label).tag($0) }
                                    }
                                    .labelsHidden()
                                    .frame(width: 210)
                                    TextField("", text: $col.language)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 46)
                                        .disabled(col.kind != .langText)
                                    TextField(";", text: $col.separator)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 56)
                                        .help("Scheidingsteken als een cel meerdere waarden bevat, bijv. ;")
                                }
                            }
                        }
                        HStack {
                            Button("Voorstellen op basis van kolomnamen") {
                                editor.mapping.applySuggestions()
                            }
                            Button("Alles aan") { setAll(true) }
                            Button("Alles uit") { setAll(false) }
                            Spacer()
                            Button("Eigen prefixen…") { showPrefixes = true }
                        }
                    }
                    .padding(6)
                }
            }
            .padding(14)
        }
    }

    private func setAll(_ value: Bool) {
        for i in editor.mapping.columns.indices {
            editor.mapping.columns[i].enabled = value && !editor.mapping.columns[i].predicate.trimmed.isEmpty
        }
    }

    // MARK: Voorbeeld

    private func previewPane(_ result: TurtleResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Turtle-voorbeeld").font(.headline)
                Spacer()
                Picker("Rijen", selection: $previewRows) {
                    Text("10 rijen").tag(10)
                    Text("25 rijen").tag(25)
                    Text("100 rijen").tag(100)
                }
                .frame(width: 130)
            }
            .padding(10)

            if !result.warnings.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(result.warnings.enumerated()), id: \.offset) { _, w in
                            Text("⚠︎ " + w)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 110)
            }
            Divider()
            ScrollView([.vertical, .horizontal]) {
                Text(result.text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Text("Voorbeeld: \(result.subjectCount) resources, \(result.tripleCount) triples")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let m = editor.statusMessage {
                    Text(m).font(.caption).foregroundStyle(.secondary)
                }
                Button("Kopieer voorbeeld") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.text, forType: .string)
                }
                Button("Exporteer Turtle…", action: onExport)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
    }
}
