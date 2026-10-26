import Foundation

// MARK: - Kleine helpers

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Scheidingsteken en tekenset

enum CSVDelimiter: String, CaseIterable, Identifiable {
    case comma, semicolon, tab, pipe

    var id: String { rawValue }

    var character: Character {
        switch self {
        case .comma: return ","
        case .semicolon: return ";"
        case .tab: return "\t"
        case .pipe: return "|"
        }
    }

    var byte: UInt8 {
        switch self {
        case .comma: return 0x2C
        case .semicolon: return 0x3B
        case .tab: return 0x09
        case .pipe: return 0x7C
        }
    }

    var label: String {
        switch self {
        case .comma: return "Komma (,)"
        case .semicolon: return "Puntkomma (;)"
        case .tab: return "Tab"
        case .pipe: return "Verticale streep (|)"
        }
    }
}

enum CSVEncoding: String, CaseIterable, Identifiable {
    case utf8, utf8BOM, windows1252, isoLatin1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 met BOM (Excel)"
        case .windows1252: return "Windows-1252"
        case .isoLatin1: return "ISO Latin-1"
        }
    }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: return .utf8
        case .windows1252: return .windowsCP1252
        case .isoLatin1: return .isoLatin1
        }
    }
}

/// Uniek, oplopend nummer per wijziging. De tabelweergave gebruikt dit om te weten of er herladen moet worden.
enum Revision {
    static var counter = 0
    static func next() -> Int {
        counter += 1
        return counter
    }
}

// MARK: - Document

struct CSVDocument {
    var headers: [String]
    var rows: [[String]]
    var delimiter: CSVDelimiter = .comma
    var encoding: CSVEncoding = .utf8
    var hasHeader: Bool = true
    var crlf: Bool = false
    var revision: Int = Revision.next()

    init() {
        headers = ["Kolom A", "Kolom B", "Kolom C"]
        rows = Array(repeating: ["", "", ""], count: 10)
    }

    var columnCount: Int { headers.count }

    mutating func touch() { revision = Revision.next() }

    // MARK: Kolomnamen

    static func columnLetter(_ index: Int) -> String {
        var n = index
        var s = ""
        repeat {
            s = String(Character(UnicodeScalar(UInt8(65 + n % 26)))) + s
            n = n / 26 - 1
        } while n >= 0
        return s
    }

    static func defaultHeader(_ index: Int) -> String { "Kolom " + columnLetter(index) }

    // MARK: Inlezen

    static func decodeText(_ data: Data) -> (String, CSVEncoding) {
        if data.count >= 3, data[data.startIndex] == 0xEF, data[data.startIndex + 1] == 0xBB, data[data.startIndex + 2] == 0xBF {
            return (String(decoding: data.dropFirst(3), as: UTF8.self), .utf8BOM)
        }
        if data.count >= 2 {
            let b0 = data[data.startIndex], b1 = data[data.startIndex + 1]
            if (b0 == 0xFF && b1 == 0xFE) || (b0 == 0xFE && b1 == 0xFF) {
                if let s = String(data: data, encoding: .utf16) { return (s, .utf8) }
            }
        }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }
        if let s = String(data: data, encoding: .windowsCP1252) { return (s, .windows1252) }
        if let s = String(data: data, encoding: .isoLatin1) { return (s, .isoLatin1) }
        return (String(decoding: data, as: UTF8.self), .utf8)
    }

    static func parseRecords(_ b: [UInt8], delimiter d: UInt8, maxRecords: Int = Int.max) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var inQuotes = false
        var i = 0
        let n = b.count

        while i < n {
            let c = b[i]
            if inQuotes {
                if c == 0x22 {
                    if i + 1 < n && b[i + 1] == 0x22 {
                        field.append(0x22)
                        i += 2
                        continue
                    }
                    inQuotes = false
                    i += 1
                    continue
                }
                field.append(c)
                i += 1
                continue
            }
            if c == 0x22 {
                if field.isEmpty { inQuotes = true } else { field.append(c) }
                i += 1
            } else if c == d {
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
                i += 1
            } else if c == 0x0A || c == 0x0D {
                if c == 0x0D && i + 1 < n && b[i + 1] == 0x0A { i += 1 }
                i += 1
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
                // lege regels overslaan
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
                if rows.count >= maxRecords { return rows }
            } else {
                field.append(c)
                i += 1
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(String(decoding: field, as: UTF8.self))
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
        }
        return rows
    }

    static func detectDelimiter(_ bytes: [UInt8]) -> CSVDelimiter {
        let sample = bytes.count > 100_000 ? Array(bytes[0..<100_000]) : bytes
        var best: CSVDelimiter = .comma
        var bestScore = 0
        for cand in [CSVDelimiter.comma, .semicolon, .tab, .pipe] {
            let recs = parseRecords(sample, delimiter: cand.byte, maxRecords: 12)
            guard let first = recs.first, first.count > 1 else { continue }
            let consistent = recs.filter { $0.count == first.count }.count
            let score = consistent * 1000 + first.count
            if score > bestScore {
                bestScore = score
                best = cand
            }
        }
        return best
    }

    static func parse(data: Data) -> CSVDocument {
        let (text, enc) = decodeText(data)
        let bytes = Array(text.utf8)
        let delim = detectDelimiter(bytes)
        var records = parseRecords(bytes, delimiter: delim.byte)

        var doc = CSVDocument()
        doc.delimiter = delim
        doc.encoding = enc
        if let nl = bytes.firstIndex(of: 0x0A), nl > 0, bytes[nl - 1] == 0x0D { doc.crlf = true }

        let width = records.reduce(0) { max($0, $1.count) }
        if width == 0 {
            doc.headers = ["Kolom A"]
            doc.rows = []
            doc.touch()
            return doc
        }
        for i in records.indices where records[i].count < width {
            records[i] += Array(repeating: "", count: width - records[i].count)
        }
        let header = records.removeFirst()
        doc.headers = header.enumerated().map { $0.element.trimmed.isEmpty ? defaultHeader($0.offset) : $0.element }
        doc.rows = records
        doc.hasHeader = true
        doc.touch()
        return doc
    }

    // MARK: Wegschrijven

    static func quote(_ s: String, delimiter: Character) -> String {
        if s.isEmpty { return s }
        let dScalar = delimiter.unicodeScalars.first!
        var needs = false
        for u in s.unicodeScalars {
            if u == "\"" || u == "\n" || u == "\r" || u == dScalar {
                needs = true
                break
            }
        }
        if !needs, let f = s.first, let l = s.last, f == " " || l == " " { needs = true }
        if !needs { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func serialized(delimiter override: CSVDelimiter? = nil) -> Data {
        let d = override ?? delimiter
        let dChar = d.character
        let dString = String(dChar)
        let nl = crlf ? "\r\n" : "\n"
        var out = ""
        out.reserveCapacity(rows.count * max(headers.count, 1) * 8)

        func line(_ fields: [String]) {
            if fields.count == 1 && fields[0].isEmpty {
                out += "\"\""
            } else {
                var first = true
                for f in fields {
                    if !first { out += dString }
                    first = false
                    out += CSVDocument.quote(f, delimiter: dChar)
                }
            }
            out += nl
        }

        if hasHeader { line(headers) }
        for r in rows { line(r) }

        switch encoding {
        case .utf8:
            return Data(out.utf8)
        case .utf8BOM:
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(out.utf8))
            return data
        case .windows1252, .isoLatin1:
            return out.data(using: encoding.stringEncoding, allowLossyConversion: true) ?? Data(out.utf8)
        }
    }

    // MARK: Bewerkingen

    mutating func setCell(row: Int, col: Int, value: String) {
        guard rows.indices.contains(row), col >= 0, col < rows[row].count else { return }
        rows[row][col] = value
    }

    mutating func insertRow(at index: Int) {
        let i = min(max(index, 0), rows.count)
        rows.insert(Array(repeating: "", count: headers.count), at: i)
    }

    mutating func deleteRows(_ indices: [Int]) {
        for i in Set(indices).sorted(by: >) where rows.indices.contains(i) {
            rows.remove(at: i)
        }
    }

    /// Dupliceert de rijen en zet de kopieën direct onder het laatste origineel.
    mutating func duplicateRows(_ indices: [Int]) {
        let sorted = Set(indices).filter { rows.indices.contains($0) }.sorted()
        guard let last = sorted.last else { return }
        let copies = sorted.map { rows[$0] }
        rows.insert(contentsOf: copies, at: last + 1)
    }

    mutating func insertColumn(at index: Int, name: String) {
        let i = min(max(index, 0), headers.count)
        headers.insert(name, at: i)
        for r in rows.indices { rows[r].insert("", at: i) }
    }

    mutating func deleteColumn(at index: Int) {
        guard headers.count > 1, headers.indices.contains(index) else { return }
        headers.remove(at: index)
        for r in rows.indices { rows[r].remove(at: index) }
    }

    mutating func renameColumn(_ index: Int, to name: String) {
        guard headers.indices.contains(index) else { return }
        headers[index] = name
    }

    static func compareCells(_ a: String, _ b: String) -> ComparisonResult {
        if let x = Double(a), let y = Double(b) {
            return x < y ? .orderedAscending : (x > y ? .orderedDescending : .orderedSame)
        }
        if a.isEmpty != b.isEmpty { return a.isEmpty ? .orderedDescending : .orderedAscending }
        return a.localizedStandardCompare(b)
    }

    mutating func sortRows(byColumn col: Int, ascending: Bool) {
        guard col >= 0, col < headers.count else { return }
        let keyed = rows.enumerated().map { (i: $0.offset, v: $0.element[col], row: $0.element) }
        let sorted = keyed.sorted { a, b in
            let c = CSVDocument.compareCells(a.v, b.v)
            if c == .orderedSame { return a.i < b.i }
            return ascending ? c == .orderedAscending : c == .orderedDescending
        }
        rows = sorted.map { $0.row }
    }

    /// Plakt een blok cellen vanaf (row, col). Breidt het aantal rijen uit als dat nodig is.
    mutating func pasteBlock(_ block: [[String]], atRow row: Int, col: Int) {
        guard !block.isEmpty else { return }
        for (bi, brow) in block.enumerated() {
            let r = row + bi
            while rows.count <= r { rows.append(Array(repeating: "", count: headers.count)) }
            for (bj, value) in brow.enumerated() {
                let c = col + bj
                if c < headers.count { rows[r][c] = value }
            }
        }
    }

    mutating func setHasHeader(_ value: Bool) {
        guard value != hasHeader else { return }
        if value {
            if !rows.isEmpty {
                let first = rows.removeFirst()
                headers = first.enumerated().map { $0.element.trimmed.isEmpty ? CSVDocument.defaultHeader($0.offset) : $0.element }
            }
            hasHeader = true
        } else {
            rows.insert(headers, at: 0)
            headers = (0..<headers.count).map { CSVDocument.defaultHeader($0) }
            hasHeader = false
        }
    }
}
