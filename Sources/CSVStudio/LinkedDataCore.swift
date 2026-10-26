import Foundation

// MARK: - Mapping-model

enum ValueKind: String, CaseIterable, Codable, Identifiable {
    case text, langText, integer, decimal, double, boolean, date, dateTime, gYear, anyURI, iri, resource, mailto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Tekst"
        case .langText: return "Tekst met taal"
        case .integer: return "Geheel getal (xsd:integer)"
        case .decimal: return "Decimaal getal (xsd:decimal)"
        case .double: return "Kommagetal (xsd:double)"
        case .boolean: return "Ja/nee (xsd:boolean)"
        case .date: return "Datum (xsd:date)"
        case .dateTime: return "Datum en tijd (xsd:dateTime)"
        case .gYear: return "Jaar (xsd:gYear)"
        case .anyURI: return "Tekst als xsd:anyURI"
        case .iri: return "URI (volledig adres)"
        case .resource: return "Verwijzing naar resource"
        case .mailto: return "E-mailadres (mailto:)"
        }
    }

    var shortName: String {
        switch self {
        case .text: return "tekst"
        case .langText: return "tekst"
        case .integer: return "xsd:integer"
        case .decimal: return "xsd:decimal"
        case .double: return "xsd:double"
        case .boolean: return "xsd:boolean"
        case .date: return "xsd:date"
        case .dateTime: return "xsd:dateTime"
        case .gYear: return "xsd:gYear"
        case .anyURI: return "xsd:anyURI"
        case .iri: return "absolute URI"
        case .resource: return "resource-verwijzing"
        case .mailto: return "e-mailadres"
        }
    }
}

struct ColumnMapping: Codable, Identifiable, Equatable {
    var id = UUID()
    var header: String
    var enabled: Bool = false
    var predicate: String = ""
    var kind: ValueKind = .text
    var language: String = ""
    var separator: String = ""
}

struct CustomPrefix: Codable, Identifiable, Equatable {
    var id = UUID()
    var prefix: String = ""
    var namespace: String = ""
}

struct LDMapping: Codable, Equatable {
    var baseURI: String = "https://example.org/id/"
    var classes: String = ""
    var subjectTemplate: String = "{#}"
    var defaultLanguage: String = "nl"
    var customPrefixes: [CustomPrefix] = []
    var columns: [ColumnMapping] = []

    /// Houdt de kolomlijst gelijk aan de kopregel van de CSV. Bestaande koppelingen blijven behouden
    /// (op naam); nieuwe kolommen krijgen, waar mogelijk, een voorgesteld predicaat.
    mutating func syncColumns(with headers: [String]) {
        var pool = columns
        var result: [ColumnMapping] = []
        for h in headers {
            if let idx = pool.firstIndex(where: { $0.header == h }) {
                result.append(pool.remove(at: idx))
            } else {
                var m = ColumnMapping(header: h)
                if let s = Suggester.suggest(for: h) {
                    m.predicate = s.predicate
                    m.kind = s.kind
                    m.separator = s.separator
                    m.enabled = true
                }
                result.append(m)
            }
        }
        columns = result
    }

    /// Vult voorstellen in voor kolommen zonder predicaat.
    mutating func applySuggestions() {
        for i in columns.indices where columns[i].predicate.trimmed.isEmpty {
            if let s = Suggester.suggest(for: columns[i].header) {
                columns[i].predicate = s.predicate
                columns[i].kind = s.kind
                columns[i].separator = s.separator
                columns[i].enabled = true
            }
        }
    }
}

// MARK: - Automatische voorstellen op basis van kolomnamen

enum Suggester {
    struct Rule {
        let names: [String]
        let predicate: String
        let kind: ValueKind
        let separator: String
    }

    static let rules: [Rule] = [
        Rule(names: ["naam", "name", "label", "benaming"], predicate: "rdfs:label", kind: .text, separator: ""),
        Rule(names: ["titel", "title"], predicate: "dcterms:title", kind: .text, separator: ""),
        Rule(names: ["voorkeursterm", "preflabel", "pref label", "preferred label", "term", "begrip", "voorkeursnaam"], predicate: "skos:prefLabel", kind: .langText, separator: ""),
        Rule(names: ["synoniem", "synoniemen", "altlabel", "alt label", "alternatieve term", "alias", "alternatieve naam"], predicate: "skos:altLabel", kind: .langText, separator: ";"),
        Rule(names: ["definitie", "definition"], predicate: "skos:definition", kind: .langText, separator: ""),
        Rule(names: ["notatie", "notation"], predicate: "skos:notation", kind: .text, separator: ""),
        Rule(names: ["opmerking", "opmerkingen", "notitie", "note", "notes", "aantekening"], predicate: "skos:note", kind: .text, separator: ""),
        Rule(names: ["omschrijving", "beschrijving", "description", "toelichting"], predicate: "dcterms:description", kind: .text, separator: ""),
        Rule(names: ["id", "identifier", "identificatie", "identificatienummer", "uuid", "guid"], predicate: "dcterms:identifier", kind: .text, separator: ""),
        Rule(names: ["auteur", "creator", "maker", "aangemaakt door"], predicate: "dcterms:creator", kind: .text, separator: ""),
        Rule(names: ["aangemaakt", "created", "creatiedatum", "datum aangemaakt", "aanmaakdatum"], predicate: "dcterms:created", kind: .date, separator: ""),
        Rule(names: ["gewijzigd", "modified", "wijzigingsdatum", "laatst gewijzigd", "datum gewijzigd"], predicate: "dcterms:modified", kind: .date, separator: ""),
        Rule(names: ["uitgegeven", "issued", "publicatiedatum", "datum publicatie"], predicate: "dcterms:issued", kind: .date, separator: ""),
        Rule(names: ["datum", "date"], predicate: "dcterms:date", kind: .date, separator: ""),
        Rule(names: ["taal", "language"], predicate: "dcterms:language", kind: .text, separator: ""),
        Rule(names: ["uitgever", "publisher"], predicate: "dcterms:publisher", kind: .text, separator: ""),
        Rule(names: ["onderwerp", "subject", "thema", "theme"], predicate: "dcterms:subject", kind: .text, separator: ""),
        Rule(names: ["licentie", "license", "licence"], predicate: "dcterms:license", kind: .text, separator: ""),
        Rule(names: ["bron", "source"], predicate: "dcterms:source", kind: .text, separator: ""),
        Rule(names: ["voornaam", "voornamen", "given name", "firstname", "first name"], predicate: "foaf:givenName", kind: .text, separator: ""),
        Rule(names: ["achternaam", "familienaam", "lastname", "last name", "surname", "family name"], predicate: "foaf:familyName", kind: .text, separator: ""),
        Rule(names: ["email", "e-mail", "mail", "e-mailadres", "emailadres", "email address"], predicate: "schema:email", kind: .text, separator: ""),
        Rule(names: ["telefoon", "telefoonnummer", "phone", "tel", "telephone", "mobiel"], predicate: "schema:telephone", kind: .text, separator: ""),
        Rule(names: ["website", "url", "homepage", "web", "link", "webadres"], predicate: "schema:url", kind: .iri, separator: ""),
        Rule(names: ["straat", "straatnaam", "street", "adres", "address", "street address"], predicate: "schema:streetAddress", kind: .text, separator: ""),
        Rule(names: ["postcode", "zip", "zipcode", "postal code"], predicate: "schema:postalCode", kind: .text, separator: ""),
        Rule(names: ["plaats", "woonplaats", "stad", "city", "gemeente", "vestigingsplaats"], predicate: "schema:addressLocality", kind: .text, separator: ""),
        Rule(names: ["land", "country"], predicate: "schema:addressCountry", kind: .text, separator: ""),
        Rule(names: ["lat", "latitude", "breedtegraad"], predicate: "geo:lat", kind: .decimal, separator: ""),
        Rule(names: ["lon", "long", "lng", "longitude", "lengtegraad"], predicate: "geo:long", kind: .decimal, separator: ""),
        Rule(names: ["bovenliggend", "broader", "parent", "bovenliggend begrip", "ouder"], predicate: "skos:broader", kind: .resource, separator: ";"),
        Rule(names: ["onderliggend", "narrower", "child", "onderliggend begrip"], predicate: "skos:narrower", kind: .resource, separator: ";"),
        Rule(names: ["gerelateerd", "related", "verwant", "gerelateerd begrip"], predicate: "skos:related", kind: .resource, separator: ";"),
        Rule(names: ["geboortedatum", "birthdate", "birth date", "date of birth"], predicate: "schema:birthDate", kind: .date, separator: ""),
        Rule(names: ["functie", "jobtitle", "job title", "functienaam"], predicate: "schema:jobTitle", kind: .text, separator: ""),
        Rule(names: ["afbeelding", "image", "foto", "logo"], predicate: "schema:image", kind: .iri, separator: ""),
        Rule(names: ["trefwoorden", "trefwoord", "keywords", "tags"], predicate: "dcat:keyword", kind: .text, separator: ";"),
        Rule(names: ["begindatum", "startdatum", "start date", "startdate", "start"], predicate: "schema:startDate", kind: .date, separator: ""),
        Rule(names: ["einddatum", "enddate", "end date", "eind"], predicate: "schema:endDate", kind: .date, separator: ""),
        Rule(names: ["prijs", "price"], predicate: "schema:price", kind: .decimal, separator: ""),
        Rule(names: ["versie", "version"], predicate: "owl:versionInfo", kind: .text, separator: ""),
        Rule(names: ["status"], predicate: "adms:status", kind: .text, separator: "")
    ]

    static let index: [String: Rule] = {
        var d = [String: Rule]()
        for r in rules {
            for n in r.names where d[n] == nil { d[n] = r }
        }
        return d
    }()

    static func suggest(for header: String) -> Rule? {
        let key = header.trimmed.lowercased().replacingOccurrences(of: "_", with: " ")
        return index[key]
    }
}

// MARK: - Bewaren van koppelingen per kolomindeling

enum MappingStore {
    private struct Defaults: Codable {
        var baseURI: String
        var defaultLanguage: String
        var customPrefixes: [CustomPrefix]
    }

    private static let defaultsKey = "ldmapping.defaults"

    static func key(headers: [String]) -> String {
        var h: UInt64 = 0xcbf29ce484222325
        for b in headers.joined(separator: "\u{1F}").utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return "ldmapping." + String(h, radix: 16)
    }

    static func load(headers: [String]) -> LDMapping? {
        guard let d = UserDefaults.standard.data(forKey: key(headers: headers)) else { return nil }
        return try? JSONDecoder().decode(LDMapping.self, from: d)
    }

    static func save(_ m: LDMapping, headers: [String]) {
        if let d = try? JSONEncoder().encode(m) {
            UserDefaults.standard.set(d, forKey: key(headers: headers))
        }
        let defaults = Defaults(baseURI: m.baseURI, defaultLanguage: m.defaultLanguage, customPrefixes: m.customPrefixes)
        if let d = try? JSONEncoder().encode(defaults) {
            UserDefaults.standard.set(d, forKey: defaultsKey)
        }
    }

    /// Nieuwe koppeling: begint met de laatst gebruikte basis-URI, taal en eigen prefixen.
    static func fresh(headers: [String]) -> LDMapping {
        var m = LDMapping()
        if let d = UserDefaults.standard.data(forKey: defaultsKey),
           let def = try? JSONDecoder().decode(Defaults.self, from: d) {
            m.baseURI = def.baseURI
            m.defaultLanguage = def.defaultLanguage
            m.customPrefixes = def.customPrefixes
        }
        let idLike: Set<String> = ["id", "identifier", "identificatie", "code", "nummer", "uri", "notatie", "notation"]
        if let h = headers.first(where: { idLike.contains($0.trimmed.lowercased()) }) {
            m.subjectTemplate = "{\(h)}"
        } else {
            m.subjectTemplate = "{#}"
        }
        return m
    }
}

// MARK: - Termen (CURIE of volledige URI) herkennen

struct TermResolver {
    let namespaces: [String: String]

    init(mapping: LDMapping) {
        var ns = Vocabularies.namespaces
        for p in mapping.customPrefixes {
            let key = p.prefix.trimmed
            let value = p.namespace.trimmed
            if !key.isEmpty, !value.isEmpty { ns[key] = value }
        }
        let base = mapping.baseURI.trimmed
        if !base.isEmpty { ns[""] = base }
        self.namespaces = ns
    }

    static func isValidLocal(_ s: String) -> Bool {
        guard let first = s.first, let last = s.last else { return false }
        if first == "-" || first == "." || last == "." { return false }
        for ch in s {
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "." { continue }
            return false
        }
        return true
    }

    /// Geeft de Turtle-schrijfwijze terug en het gebruikte voorvoegsel (indien van toepassing).
    func resolve(_ raw: String) -> (term: String, prefix: String?)? {
        let t = raw.trimmed
        if t.isEmpty { return nil }
        if t == "a" { return ("a", nil) }
        if t.hasPrefix("<") && t.hasSuffix(">") && t.count > 2 {
            return ("<" + TurtleWriter.escapeIRI(String(t.dropFirst().dropLast())) + ">", nil)
        }
        if t.contains("://") || t.hasPrefix("urn:") {
            return ("<" + TurtleWriter.escapeIRI(t) + ">", nil)
        }
        guard let colon = t.firstIndex(of: ":") else { return nil }
        let prefix = String(t[t.startIndex..<colon])
        let local = String(t[t.index(after: colon)...])
        guard !local.isEmpty, let ns = namespaces[prefix] else { return nil }
        if prefix == "rdf" && local == "type" { return ("a", nil) }
        if TermResolver.isValidLocal(local) { return (prefix + ":" + local, prefix) }
        return ("<" + TurtleWriter.escapeIRI(ns + local) + ">", nil)
    }

    func isResolvable(_ raw: String) -> Bool { resolve(raw) != nil }
}

// MARK: - Turtle genereren

struct TurtleResult {
    var text: String
    var warnings: [String]
    var subjectCount: Int
    var tripleCount: Int
}

struct TurtleWriter {
    let mapping: LDMapping
    let headers: [String]

    // MARK: Reguliere expressies (eenmalig gecompileerd)

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }

    private static let reInteger = re("^[+-]?[0-9]+$")
    private static let reDecimal = re("^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)$")
    private static let reDouble = re("^([+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?|[+-]?INF|NaN)$")
    private static let reGYear = re("^-?[0-9]{4,}$")
    private static let reISODate = re("^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$")
    private static let reNLDate = re("^([0-9]{1,2})[-/.]([0-9]{1,2})[-/.]([0-9]{4})$")
    private static let reISODateTime = re("^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})[T ]([0-9]{1,2}):([0-9]{2})(?::([0-9]{2})(\\.[0-9]+)?)?\\s*(Z|[+-][0-9]{2}:?[0-9]{2})?$")
    private static let reNLDateTime = re("^([0-9]{1,2})[-/.]([0-9]{1,2})[-/.]([0-9]{4})[T ]([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?$")
    private static let reScheme = re("^[A-Za-z][A-Za-z0-9+.\\-]*:")
    private static let reAbsIRI = re("^[A-Za-z][A-Za-z0-9+.\\-]*:[^\\s]+$")
    private static let reLang = re("^[A-Za-z]{1,8}(-[A-Za-z0-9]{1,8})*$")

    private static func matches(_ r: NSRegularExpression, _ s: String) -> Bool {
        let ns = NSString(string: s)
        return r.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)) != nil
    }

    private static func captures(_ r: NSRegularExpression, _ s: String) -> [String]? {
        let ns = NSString(string: s)
        guard let m = r.firstMatch(in: s, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        var out: [String] = []
        for i in 0..<m.numberOfRanges {
            let range = m.range(at: i)
            out.append(range.location == NSNotFound ? "" : ns.substring(with: range))
        }
        return out
    }

    // MARK: Escapes

    static func escapeLiteral(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count + 2)
        for u in s.unicodeScalars {
            switch u {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 || u.value == 0x7F {
                    out += String(format: "\\u%04X", u.value)
                } else {
                    out.unicodeScalars.append(u)
                }
            }
        }
        return out
    }

    private static let iriForbidden: Set<UInt32> = Set("<>\"{}|^`\\".unicodeScalars.map { $0.value })

    static func escapeIRI(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            let v = u.value
            if v <= 0x20 || v == 0x7F || iriForbidden.contains(v) {
                out += String(format: "%%%02X", v)
            } else {
                out.unicodeScalars.append(u)
            }
        }
        return out
    }

    private static let slugAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()

    /// Maakt van een celwaarde een bruikbaar IRI-fragment.
    static func slug(_ s: String) -> String {
        let t = s.trimmed
        var out = ""
        var lastDash = false
        for u in t.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(u) {
                if !lastDash {
                    out += "-"
                    lastDash = true
                }
                continue
            }
            lastDash = false
            if slugAllowed.contains(u) {
                out.unicodeScalars.append(u)
            } else {
                for b in String(u).utf8 { out += String(format: "%%%02X", UInt32(b)) }
            }
        }
        return out
    }

    private static func isSimpleLocal(_ s: String) -> Bool {
        guard let first = s.unicodeScalars.first, first != "-" else { return false }
        for u in s.unicodeScalars {
            let v = u.value
            let ok = (v >= 0x30 && v <= 0x39) || (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) || v == 0x5F || v == 0x2D
            if !ok { return false }
        }
        return true
    }

    private static func hasScheme(_ s: String) -> Bool { matches(reScheme, s) }
    private static func isAbsoluteIRI(_ s: String) -> Bool { matches(reAbsIRI, s) }

    // MARK: Waarden omzetten

    private static func validYMD(_ y: Int, _ m: Int, _ d: Int) -> Bool {
        guard m >= 1, m <= 12, d >= 1 else { return false }
        let days = [31, (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return d <= days[m - 1]
    }

    static func normalizeDate(_ s: String) -> String? {
        if let c = captures(reISODate, s), let y = Int(c[1]), let m = Int(c[2]), let d = Int(c[3]), validYMD(y, m, d) {
            return String(format: "%04d-%02d-%02d", y, m, d)
        }
        if let c = captures(reNLDate, s), let d = Int(c[1]), let m = Int(c[2]), let y = Int(c[3]), validYMD(y, m, d) {
            return String(format: "%04d-%02d-%02d", y, m, d)
        }
        return nil
    }

    static func normalizeDateTime(_ s: String) -> String? {
        if let c = captures(reISODateTime, s),
           let y = Int(c[1]), let mo = Int(c[2]), let d = Int(c[3]),
           let h = Int(c[4]), let mi = Int(c[5]), validYMD(y, mo, d), h < 24, mi < 60 {
            let sec = c[6].isEmpty ? 0 : (Int(c[6]) ?? 0)
            if sec > 59 { return nil }
            var tz = c[8]
            if tz.count == 5, tz.first == "+" || tz.first == "-" {
                tz = String(tz.prefix(3)) + ":" + String(tz.suffix(2))
            }
            return String(format: "%04d-%02d-%02dT%02d:%02d:%02d", y, mo, d, h, mi, sec) + c[7] + tz
        }
        if let c = captures(reNLDateTime, s),
           let d = Int(c[1]), let mo = Int(c[2]), let y = Int(c[3]),
           let h = Int(c[4]), let mi = Int(c[5]), validYMD(y, mo, d), h < 24, mi < 60 {
            let sec = c[6].isEmpty ? 0 : (Int(c[6]) ?? 0)
            if sec > 59 { return nil }
            return String(format: "%04d-%02d-%02dT%02d:%02d:%02d", y, mo, d, h, mi, sec)
        }
        if let date = normalizeDate(s) { return date + "T00:00:00" }
        return nil
    }

    static func parseBoolean(_ s: String) -> String? {
        switch s.lowercased() {
        case "true", "1", "ja", "yes", "waar", "j", "y": return "true"
        case "false", "0", "nee", "no", "onwaar", "n": return "false"
        default: return nil
        }
    }

    private static func normalizeNumber(_ v: String) -> String {
        if !v.contains("."), v.filter({ $0 == "," }).count == 1 {
            return v.replacingOccurrences(of: ",", with: ".")
        }
        return v
    }

    // MARK: Genereren

    private enum Part {
        case text(String)
        case rownum
        case column(Int)
    }

    func columnIndex(named name: String) -> Int? {
        if let i = headers.firstIndex(of: name) { return i }
        let key = name.trimmed.lowercased()
        return headers.firstIndex { $0.trimmed.lowercased() == key }
    }

    func generate(rows: [[String]], range: Range<Int>, sourceName: String) -> TurtleResult {
        var warnings: [String] = []
        var used = Set<String>()
        let resolver = TermResolver(mapping: mapping)
        let base = mapping.baseURI.trimmed

        func resolve(_ raw: String) -> String? {
            guard let r = resolver.resolve(raw) else { return nil }
            if let p = r.prefix { used.insert(p) }
            return r.term
        }

        // Basis-URI controleren
        if base.isEmpty {
            warnings.append("Basis-URI is leeg: subject-URI’s worden relatief.")
        } else if !TurtleWriter.hasScheme(base) {
            warnings.append("Basis-URI lijkt geen geldig absoluut adres (bijv. https://example.org/id/).")
        }

        // Klassen
        var classTerms: [String] = []
        for piece in mapping.classes.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let raw = String(piece).trimmed
            if raw.isEmpty { continue }
            if let t = resolve(raw) { classTerms.append(t) } else { warnings.append("Onbekende klasse ‘\(raw)’ (voorvoegsel niet bekend).") }
        }

        // Subject-sjabloon
        var parts: [Part] = []
        do {
            let t = mapping.subjectTemplate
            var literal = ""
            var i = t.startIndex
            while i < t.endIndex {
                let ch = t[i]
                if ch == "{", let close = t[i...].firstIndex(of: "}") {
                    let name = String(t[t.index(after: i)..<close])
                    if !literal.isEmpty {
                        parts.append(.text(literal))
                        literal = ""
                    }
                    if name == "#" {
                        parts.append(.rownum)
                    } else if let idx = columnIndex(named: name) {
                        parts.append(.column(idx))
                    } else {
                        warnings.append("Subject-sjabloon verwijst naar onbekende kolom ‘\(name)’.")
                    }
                    i = t.index(after: close)
                } else {
                    literal.append(ch)
                    i = t.index(after: i)
                }
            }
            if !literal.isEmpty { parts.append(.text(literal)) }
        }
        var hasPlaceholder = false
        for p in parts {
            if case .text = p { continue }
            hasPlaceholder = true
        }

        func subjectRef(_ local: String) -> String {
            if base.isEmpty { return "<" + local + ">" }
            if TurtleWriter.isSimpleLocal(local) {
                used.insert("")
                return ":" + local
            }
            return "<" + TurtleWriter.escapeIRI(base) + local + ">"
        }

        func subject(row: [String], number: Int) -> String? {
            if parts.isEmpty { return nil }
            if parts.count == 1, case .column(let c) = parts[0] {
                let v = (c < row.count ? row[c] : "").trimmed
                if TurtleWriter.isAbsoluteIRI(v) { return "<" + TurtleWriter.escapeIRI(v) + ">" }
            }
            var s = ""
            var anyValue = !hasPlaceholder
            for p in parts {
                switch p {
                case .text(let t):
                    s += TurtleWriter.escapeIRI(t)
                case .rownum:
                    s += String(number)
                    anyValue = true
                case .column(let c):
                    let v = TurtleWriter.slug(c < row.count ? row[c] : "")
                    if !v.isEmpty { anyValue = true }
                    s += v
                }
            }
            if !anyValue || s.isEmpty { return nil }
            if TurtleWriter.hasScheme(s) { return "<" + s + ">" }
            return subjectRef(s)
        }

        // Actieve kolommen
        struct Active {
            let index: Int
            let term: String
            let kind: ValueKind
            let lang: String
            let separator: String
            let header: String
        }
        var active: [Active] = []
        for (ci, col) in mapping.columns.enumerated() where col.enabled {
            guard ci < headers.count else { continue }
            let pred = col.predicate.trimmed
            if pred.isEmpty {
                warnings.append("Kolom ‘\(col.header)’ is aan, maar heeft geen predicaat.")
                continue
            }
            guard let term = resolve(pred) else {
                warnings.append("Kolom ‘\(col.header)’: predicaat ‘\(pred)’ is ongeldig of het voorvoegsel is onbekend.")
                continue
            }
            var lang = ""
            if col.kind == .langText {
                let l = (col.language.trimmed.isEmpty ? mapping.defaultLanguage : col.language).trimmed
                if l.isEmpty {
                    lang = ""
                } else if TurtleWriter.matches(TurtleWriter.reLang, l) {
                    lang = l
                } else {
                    warnings.append("Kolom ‘\(col.header)’: taalcode ‘\(l)’ is ongeldig; tekst zonder taal gebruikt.")
                }
            }
            active.append(Active(index: ci, term: term, kind: col.kind, lang: lang, separator: col.separator, header: col.header))
        }
        if active.isEmpty && classTerms.isEmpty {
            warnings.append("Er zijn nog geen kolommen aan een predicaat gekoppeld.")
        }

        // Waarde → Turtle-term
        var invalidCounts: [Int: Int] = [:]

        func quoted(_ v: String) -> String { "\"" + TurtleWriter.escapeLiteral(v) + "\"" }
        func typed(_ lexical: String, _ type: String) -> String {
            used.insert("xsd")
            return "\"" + TurtleWriter.escapeLiteral(lexical) + "\"^^xsd:" + type
        }
        func resourceRef(_ v: String) -> String {
            if TurtleWriter.isAbsoluteIRI(v) { return "<" + TurtleWriter.escapeIRI(v) + ">" }
            return subjectRef(TurtleWriter.slug(v))
        }

        func makeTerm(_ v: String, _ a: Active) -> String? {
            switch a.kind {
            case .text:
                return quoted(v)
            case .langText:
                return a.lang.isEmpty ? quoted(v) : quoted(v) + "@" + a.lang
            case .integer:
                return TurtleWriter.matches(TurtleWriter.reInteger, v) ? typed(v, "integer") : nil
            case .decimal:
                let n = TurtleWriter.normalizeNumber(v)
                return TurtleWriter.matches(TurtleWriter.reDecimal, n) ? typed(n, "decimal") : nil
            case .double:
                let n = TurtleWriter.normalizeNumber(v)
                return TurtleWriter.matches(TurtleWriter.reDouble, n) ? typed(n, "double") : nil
            case .boolean:
                if let b = TurtleWriter.parseBoolean(v) { return typed(b, "boolean") }
                return nil
            case .date:
                if let d = TurtleWriter.normalizeDate(v) { return typed(d, "date") }
                return nil
            case .dateTime:
                if let d = TurtleWriter.normalizeDateTime(v) { return typed(d, "dateTime") }
                return nil
            case .gYear:
                return TurtleWriter.matches(TurtleWriter.reGYear, v) ? typed(v, "gYear") : nil
            case .anyURI:
                return typed(v, "anyURI")
            case .iri:
                return TurtleWriter.isAbsoluteIRI(v) ? "<" + TurtleWriter.escapeIRI(v) + ">" : nil
            case .resource:
                let r = resourceRef(v)
                return r == "<>" ? nil : r
            case .mailto:
                if v.contains("@") && !v.contains(" ") { return "<mailto:" + TurtleWriter.escapeIRI(v) + ">" }
                return nil
            }
        }

        // Rijen
        var body = ""
        body.reserveCapacity(range.count * 120)
        var subjectCount = 0
        var tripleCount = 0
        var skippedEmpty = 0
        var blankSubjects = 0
        var duplicates = 0
        var seen = Set<String>()

        for r in range {
            let row = rows[r]
            let number = r + 1
            var pairs: [(pred: String, objs: [String])] = []
            if !classTerms.isEmpty {
                pairs.append((pred: "a", objs: classTerms))
                tripleCount += classTerms.count
            }
            for a in active {
                let raw = a.index < row.count ? row[a.index] : ""
                if raw.trimmed.isEmpty { continue }
                let pieces: [String] = a.separator.isEmpty ? [raw] : raw.components(separatedBy: a.separator)
                var objs: [String] = []
                for piece in pieces {
                    let v = piece.trimmed
                    if v.isEmpty { continue }
                    if let t = makeTerm(v, a) {
                        objs.append(t)
                    } else {
                        invalidCounts[a.index, default: 0] += 1
                        objs.append(quoted(v))
                    }
                }
                if !objs.isEmpty {
                    pairs.append((pred: a.term, objs: objs))
                    tripleCount += objs.count
                }
            }
            if pairs.isEmpty {
                skippedEmpty += 1
                continue
            }
            let subj: String
            if let s = subject(row: row, number: number) {
                subj = s
                if !seen.insert(s).inserted { duplicates += 1 }
            } else {
                subj = "_:r\(number)"
                blankSubjects += 1
            }
            subjectCount += 1
            body += subj
            body += "\n"
            for (i, p) in pairs.enumerated() {
                body += "    " + p.pred + " " + p.objs.joined(separator: ", ")
                body += i == pairs.count - 1 ? " .\n" : " ;\n"
            }
            body += "\n"
        }

        for a in active {
            if let n = invalidCounts[a.index], n > 0 {
                warnings.append("Kolom ‘\(a.header)’: \(n) waarde(n) zijn geen geldige \(a.kind.shortName); als gewone tekst opgenomen.")
            }
        }
        if duplicates > 0 {
            warnings.append("\(duplicates) rij(en) hebben dezelfde subject-URI als een eerdere rij; hun gegevens worden samengevoegd. Kies een uniekere subject-URI.")
        }
        if blankSubjects > 0 {
            warnings.append("\(blankSubjects) rij(en) zonder waarde voor de subject-URI kregen een blank node.")
        }
        if skippedEmpty > 0 {
            warnings.append("\(skippedEmpty) rij(en) zonder gekoppelde waarden zijn overgeslagen.")
        }

        // Kop met voorvoegsels
        var head = ""
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let source = sourceName.replacingOccurrences(of: "\n", with: " ")
        head += "# Gegenereerd door CSV Studio op \(dateFormatter.string(from: Date())) uit \(source)\n"
        for p in used.sorted() {
            if let ns = resolver.namespaces[p] {
                head += "@prefix \(p): <\(TurtleWriter.escapeIRI(ns))> .\n"
            }
        }
        head += "\n"

        return TurtleResult(text: head + body, warnings: warnings, subjectCount: subjectCount, tripleCount: tripleCount)
    }
}
