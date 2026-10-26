import Foundation

// MARK: - CRC32 en zip (zonder compressie, geen externe afhankelijkheden)

enum CRC32 {
    static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> Void in
            for b in buf {
                c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8)
            }
        }
        return c ^ 0xFFFFFFFF
    }
}

extension Data {
    mutating func appendLE16(_ v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
    }

    mutating func appendLE32(_ v: UInt32) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 24) & 0xFF))
    }
}

struct ZipWriter {
    private struct Entry {
        let name: [UInt8]
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    private var data = Data()
    private var entries: [Entry] = []

    mutating func add(_ name: String, _ content: Data) {
        let nameBytes = Array(name.utf8)
        let crc = CRC32.checksum(content)
        let size = UInt32(content.count)
        let offset = UInt32(data.count)

        data.appendLE32(0x04034B50)          // local file header
        data.appendLE16(20)                  // version needed
        data.appendLE16(0x0800)              // flags: UTF-8 bestandsnamen
        data.appendLE16(0)                   // methode: stored
        data.appendLE16(0)                   // tijd
        data.appendLE16(33)                  // datum 1980-01-01
        data.appendLE32(crc)
        data.appendLE32(size)
        data.appendLE32(size)
        data.appendLE16(UInt16(nameBytes.count))
        data.appendLE16(0)                   // extra length
        data.append(contentsOf: nameBytes)
        data.append(content)

        entries.append(Entry(name: nameBytes, crc: crc, size: size, offset: offset))
    }

    mutating func finish() -> Data {
        let cdStart = UInt32(data.count)
        for e in entries {
            data.appendLE32(0x02014B50)      // central directory header
            data.appendLE16(20)              // version made by
            data.appendLE16(20)              // version needed
            data.appendLE16(0x0800)
            data.appendLE16(0)
            data.appendLE16(0)
            data.appendLE16(33)
            data.appendLE32(e.crc)
            data.appendLE32(e.size)
            data.appendLE32(e.size)
            data.appendLE16(UInt16(e.name.count))
            data.appendLE16(0)               // extra
            data.appendLE16(0)               // comment
            data.appendLE16(0)               // disk start
            data.appendLE16(0)               // internal attrs
            data.appendLE32(0)               // external attrs
            data.appendLE32(e.offset)
            data.append(contentsOf: e.name)
        }
        let cdSize = UInt32(data.count) - cdStart
        data.appendLE32(0x06054B50)          // end of central directory
        data.appendLE16(0)
        data.appendLE16(0)
        data.appendLE16(UInt16(entries.count))
        data.appendLE16(UInt16(entries.count))
        data.appendLE32(cdSize)
        data.appendLE32(cdStart)
        data.appendLE16(0)
        return data
    }
}

// MARK: - XLSX

enum XLSXWriter {
    struct Output {
        let data: Data
        let truncated: Bool
    }

    static let maxRows = 1_048_576
    static let maxCols = 16_384
    static let maxCellLength = 32_767

    static func columnName(_ index: Int) -> String {
        CSVDocument.columnLetter(index)
    }

    static func xmlEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        var count = 0
        for u in s.unicodeScalars {
            if count >= maxCellLength { break }
            count += 1
            switch u.value {
            case 0x26: out += "&amp;"
            case 0x3C: out += "&lt;"
            case 0x3E: out += "&gt;"
            case 0x22: out += "&quot;"
            case 0x09, 0x0A, 0x0D: out.unicodeScalars.append(u)
            case 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: out.unicodeScalars.append(u)
            default: break // ongeldige XML-tekens weglaten
            }
        }
        return out
    }

    /// Geeft de waarde terug als hij veilig als getal kan worden opgeslagen
    /// (geen voorloopnullen, niet te lang, geen afsluitende nullen), anders nil.
    static func numericValue(_ s: String) -> String? {
        let u = Array(s.utf8)
        if u.isEmpty || u.count > 17 { return nil }
        var i = 0
        if u[0] == 0x2D { i = 1 }
        let intStart = i
        while i < u.count, u[i] >= 0x30, u[i] <= 0x39 { i += 1 }
        let intLen = i - intStart
        if intLen == 0 { return nil }
        if intLen > 1 && u[intStart] == 0x30 { return nil }
        var fracLen = 0
        if i < u.count {
            guard u[i] == 0x2E else { return nil }
            i += 1
            let fs = i
            while i < u.count, u[i] >= 0x30, u[i] <= 0x39 { i += 1 }
            fracLen = i - fs
            if fracLen == 0 || i != u.count { return nil }
            if u[u.count - 1] == 0x30 { return nil }
        }
        if intLen + fracLen > 15 { return nil }
        if s == "-0" { return nil }
        return s
    }

    static func sanitizedSheetName(_ name: String) -> String {
        var s = name
        for bad in ["[", "]", ":", "*", "?", "/", "\\"] {
            s = s.replacingOccurrences(of: bad, with: " ")
        }
        s = s.trimmed
        while s.hasPrefix("'") { s.removeFirst() }
        while s.hasSuffix("'") { s.removeLast() }
        if s.isEmpty { s = "Blad1" }
        return String(s.prefix(31))
    }

    static func make(headers: [String], rows allRows: [[String]], includeHeader: Bool, sheetName: String) -> Output {
        let cols = min(headers.count, maxCols)
        var truncated = headers.count > maxCols

        // Rijen beperken (de kopregel telt mee)
        let capacity = includeHeader ? maxRows - 1 : maxRows
        let rows: ArraySlice<[String]>
        if allRows.count > capacity {
            rows = allRows.prefix(capacity)
            truncated = true
        } else {
            rows = allRows[...]
        }

        let totalRows = rows.count + (includeHeader ? 1 : 0)
        let colNames = (0..<max(cols, 1)).map { columnName($0) }

        // Kolombreedtes op basis van de eerste 1000 rijen
        var widths = [Int](repeating: 8, count: cols)
        if includeHeader {
            for c in 0..<cols { widths[c] = max(widths[c], min(headers[c].count + 3, 60)) }
        }
        for r in rows.prefix(1000) {
            for c in 0..<min(cols, r.count) {
                widths[c] = max(widths[c], min(r[c].count + 2, 60))
            }
        }

        var xml = ""
        xml.reserveCapacity(totalRows * max(cols, 1) * 40 + 2048)
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">"
        if includeHeader {
            xml += "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
        }
        xml += "<sheetFormatPr defaultRowHeight=\"15\"/>"
        if cols > 0 {
            xml += "<cols>"
            for c in 0..<cols {
                xml += "<col min=\"\(c + 1)\" max=\"\(c + 1)\" width=\"\(widths[c])\" customWidth=\"1\"/>"
            }
            xml += "</cols>"
        }
        xml += "<sheetData>"

        var rowNumber = 1
        if includeHeader {
            xml += "<row r=\"1\">"
            for c in 0..<cols {
                let h = headers[c]
                if h.isEmpty { continue }
                xml += "<c r=\"\(colNames[c])1\" s=\"1\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(h))</t></is></c>"
            }
            xml += "</row>"
            rowNumber = 2
        }
        for r in rows {
            xml += "<row r=\"\(rowNumber)\">"
            for c in 0..<min(cols, r.count) {
                let v = r[c]
                if v.isEmpty { continue }
                if let num = numericValue(v) {
                    xml += "<c r=\"\(colNames[c])\(rowNumber)\"><v>\(num)</v></c>"
                } else {
                    xml += "<c r=\"\(colNames[c])\(rowNumber)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(v))</t></is></c>"
                }
            }
            xml += "</row>"
            rowNumber += 1
        }
        xml += "</sheetData>"

        let name = sanitizedSheetName(sheetName)
        var definedNames = ""
        if includeHeader && cols > 0 && totalRows > 1 {
            let ref = "A1:\(colNames[cols - 1])\(totalRows)"
            xml += "<autoFilter ref=\"\(ref)\"/>"
            let absRef = "$A$1:$\(colNames[cols - 1])$\(totalRows)"
            let quotedName = "'" + name.replacingOccurrences(of: "'", with: "''") + "'"
            definedNames = "<definedNames><definedName name=\"_xlnm._FilterDatabase\" localSheetId=\"0\" hidden=\"1\">\(xmlEscape(quotedName))!\(absRef)</definedName></definedNames>"
        }
        xml += "</worksheet>"

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """

        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="\(xmlEscape(name))" sheetId="1" r:id="rId1"/></sheets>\(definedNames)</workbook>
        """

        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
        """

        let styles = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
        """

        var zip = ZipWriter()
        zip.add("[Content_Types].xml", Data(contentTypes.utf8))
        zip.add("_rels/.rels", Data(rootRels.utf8))
        zip.add("xl/workbook.xml", Data(workbook.utf8))
        zip.add("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8))
        zip.add("xl/styles.xml", Data(styles.utf8))
        zip.add("xl/worksheets/sheet1.xml", Data(xml.utf8))
        return Output(data: zip.finish(), truncated: truncated)
    }
}
