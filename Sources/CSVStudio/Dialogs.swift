import AppKit
import UniformTypeIdentifiers

enum Dialogs {
    /// Toont een bewaar-paneel voor een export (Excel, Turtle, ...).
    static func askSaveURL(ext: String, conformingTo: UTType = .data, name: String, title: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = name + "." + ext
        if let type = UTType(filenameExtension: ext, conformingTo: conformingTo) {
            panel.allowedContentTypes = [type]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Eenvoudige invoervraag met één tekstveld. Geeft nil bij annuleren.
    static func promptText(title: String, message: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Annuleer")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    static func showError(_ error: Error) {
        NSAlert(error: error).runModal()
    }
}
