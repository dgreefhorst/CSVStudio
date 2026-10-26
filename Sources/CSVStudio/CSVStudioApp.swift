import SwiftUI
import AppKit
import UniformTypeIdentifiers

// `@State` is een macro die alleen met de volledige Xcode-toolchain werkt (SwiftUIMacros).
// Deze typealias naar de gelijkwaardige property wrapper werkt ook met de Command Line Tools.
typealias ViewState<Value> = SwiftUICore.State<Value>

// MARK: - Documenttype

extension CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .tabSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText, .tabSeparatedText, .plainText] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self = CSVDocument.parse(data: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        var override: CSVDelimiter?
        if configuration.contentType.conforms(to: .tabSeparatedText) {
            override = .tab
        } else if configuration.contentType.conforms(to: .commaSeparatedText), delimiter == .tab {
            override = .comma
        }
        return FileWrapper(regularFileWithContents: serialized(delimiter: override))
    }
}

// MARK: - App

@main
struct CSVStudioApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: CSVDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands { AppCommands() }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.csvActions) private var actions

    var body: some Commands {
        // Het standaardgroepje van Opslaan wordt bewust NIET vervangen: SwiftUI
        // laat dan een leeg item "NSMenuItem" achter en de optie
        // "Open recente bestanden" verdwijnt uit het Archief-menu.
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Exporteer als Excel (.xlsx)…") { actions?.exportExcel() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Openen in Excel") { actions?.openInExcel() }
                .keyboardShortcut("e", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Exporteer als Linked Data (.ttl)…") { actions?.exportTurtle() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandMenu("Gegevens") {
            Button("Toon tabel") { actions?.showTable() }
                .keyboardShortcut("1")
                .disabled(actions == nil)
            Button("Toon Linked Data") { actions?.showLinkedData() }
                .keyboardShortcut("2")
                .disabled(actions == nil)
            Divider()
            Button("Rij toevoegen") { actions?.addRow() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Geselecteerde rij(en) verwijderen") { actions?.deleteRows() }
                .disabled(actions == nil)
            Button("Kolom toevoegen…") { actions?.addColumn() }
                .disabled(actions == nil)
        }
    }
}
