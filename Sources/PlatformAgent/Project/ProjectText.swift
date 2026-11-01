//  WHAT: A project.pbxproj as text, read by the grammar it is written in (OpenStep plists: dictionaries, arrays,
//        quoted and bare strings, comments) and edited by splicing, so everything a call does not touch stays
//        byte for byte as Xcode wrote it.
//  PIN:  FOUND BY GRAMMAR, NOT BY LAYOUT. An object is the entry of `objects` keyed by its id, wherever the lines
//        break, so an id quoted elsewhere (a reference, a TargetAttributes key) is never mistaken for it.
//  PIN:  WRITTEN AS XCODE WRITES. Objects go in their isa's section in id order, keys in order with isa first,
//        list items one a line with their comment, so Xcode's next save moves nothing a call wrote.

import Foundation

struct ProjectText {
    private(set) var bytes: [UInt8]

    init(_ text: String) { bytes = Array(text.utf8) }

    var text: String { String(decoding: bytes, as: UTF8.self) }

    /// A `key = value;` of a dictionary.
    struct Entry {
        let key: String
        /// Where its line starts (before the indentation) when it begins the line; where its key starts otherwise.
        let line: Int
        /// Whether it begins its line.
        let ownLine: Bool
        /// The value's first byte, and one past its last.
        let value: Int
        let valueEnd: Int
        /// One past its `;`.
        let end: Int
    }

    /// An item of an array: its first token (an id, a path), and where it lies.
    struct Item {
        let token: String
        let line: Int
        let ownLine: Bool
        let start: Int
        let end: Int
    }

    // MARK: - Reading

    private static let (tab, newline, space, quote, slash, star, backslash): (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0x09, 0x0A, 0x20, 0x22, 0x2F, 0x2A, 0x5C)
    private static let (openBrace, closeBrace, openParen, closeParen, equals, semicolon, comma, less, greater): (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0x7B, 0x7D, 0x28, 0x29, 0x3D, 0x3B, 0x2C, 0x3C, 0x3E)

    private static func isBare(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
            || byte == 0x5F || byte == 0x24 || byte == 0x2B || byte == 0x2F || byte == 0x3A || byte == 0x2E || byte == 0x2D
    }

    /// Past whitespace and comments from `start`.
    func skip(_ start: Int) -> Int {
        var i = start
        while i < bytes.count {
            let byte = bytes[i]
            if byte == Self.space || byte == Self.tab || byte == Self.newline || byte == 0x0D { i += 1; continue }
            if byte == Self.slash, i + 1 < bytes.count, bytes[i + 1] == Self.star {
                i += 2
                while i + 1 < bytes.count, !(bytes[i] == Self.star && bytes[i + 1] == Self.slash) { i += 1 }
                i = min(i + 2, bytes.count)
                continue
            }
            if byte == Self.slash, i + 1 < bytes.count, bytes[i + 1] == Self.slash {
                while i < bytes.count, bytes[i] != Self.newline { i += 1 }
                continue
            }
            break
        }
        return i
    }

    /// One past the end of the value that starts at `start`.
    func valueEnd(_ start: Int) -> Int {
        guard start < bytes.count else { return start }
        switch bytes[start] {
        case Self.openBrace, Self.openParen: return closing(start) + 1
        case Self.quote: return quotedEnd(start)
        case Self.less:
            var i = start
            while i < bytes.count, bytes[i] != Self.greater { i += 1 }
            return min(i + 1, bytes.count)
        default:
            var i = start
            while i < bytes.count, Self.isBare(bytes[i]) { i += 1 }
            return i
        }
    }

    private func quotedEnd(_ start: Int) -> Int {
        var i = start + 1
        while i < bytes.count {
            if bytes[i] == Self.backslash { i += 2; continue }
            if bytes[i] == Self.quote { return i + 1 }
            i += 1
        }
        return bytes.count
    }

    /// The `}` or `)` that closes the bracket at `open`.
    func closing(_ open: Int) -> Int {
        var depth = 0, i = open
        while i < bytes.count {
            let byte = bytes[i]
            if byte == Self.quote { i = quotedEnd(i); continue }
            if byte == Self.slash, i + 1 < bytes.count, bytes[i + 1] == Self.star || bytes[i + 1] == Self.slash { i = skip(i); continue }
            if byte == Self.openBrace || byte == Self.openParen { depth += 1 }
            else if byte == Self.closeBrace || byte == Self.closeParen {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return bytes.count - 1
    }

    /// The string a token says: a quoted one unescaped, a bare one as it is.
    func token(_ start: Int, _ end: Int) -> String {
        guard start < end else { return "" }
        guard bytes[start] == Self.quote, end - start >= 2 else { return String(decoding: bytes[start..<end], as: UTF8.self) }
        var out: [UInt8] = [], i = start + 1
        while i < end - 1 {
            if bytes[i] == Self.backslash, i + 1 < end - 1 {
                let next = bytes[i + 1]
                out.append(next == 0x6E ? Self.newline : next == 0x74 ? Self.tab : next)
                i += 2
            } else {
                out.append(bytes[i]); i += 1
            }
        }
        return String(decoding: out, as: UTF8.self)
    }

    /// Whether only indentation stands between the line's start and `index`.
    func beginsLine(_ index: Int) -> Bool {
        var i = index
        while i > 0, bytes[i - 1] == Self.space || bytes[i - 1] == Self.tab { i -= 1 }
        return i == 0 || bytes[i - 1] == Self.newline
    }

    /// Where the line holding `index` starts, when only indentation stands before it; `index` otherwise.
    func lineStart(_ index: Int) -> Int {
        var i = index
        while i > 0, bytes[i - 1] == Self.space || bytes[i - 1] == Self.tab { i -= 1 }
        return i == 0 || bytes[i - 1] == Self.newline ? i : index
    }

    /// The indentation of the line that starts at `line`.
    func indentation(_ line: Int) -> String {
        var i = line
        while i < bytes.count, bytes[i] == Self.space || bytes[i] == Self.tab { i += 1 }
        return String(decoding: bytes[line..<i], as: UTF8.self)
    }

    /// The indentation an entry or item inside the bracket at `open` takes: one deeper than the bracket's line.
    func innerIndentation(_ open: Int) -> String {
        var start = open
        while start > 0, bytes[start - 1] != Self.newline { start -= 1 }
        return indentation(start) + "\t"
    }

    /// The entries of the dictionary whose `{` is at `open`.
    func entries(_ open: Int) -> [Entry] {
        var found: [Entry] = []
        var i = skip(open + 1)
        while i < bytes.count, bytes[i] != Self.closeBrace {
            let keyEnd = valueEnd(i)
            guard keyEnd > i else { break }
            var j = skip(keyEnd)
            guard j < bytes.count, bytes[j] == Self.equals else { break }
            j = skip(j + 1)
            let end = valueEnd(j)
            guard end > j else { break }
            var k = skip(end)
            guard k < bytes.count, bytes[k] == Self.semicolon else { break }
            k += 1
            found.append(Entry(key: token(i, keyEnd), line: lineStart(i), ownLine: beginsLine(i), value: j, valueEnd: end, end: k))
            i = skip(k)
        }
        return found
    }

    /// The items of the array whose `(` is at `open`.
    func items(_ open: Int) -> [Item] {
        var found: [Item] = []
        var i = skip(open + 1)
        while i < bytes.count, bytes[i] != Self.closeParen {
            let end = valueEnd(i)
            guard end > i else { break }
            var k = skip(end)
            if k < bytes.count, bytes[k] == Self.comma { k += 1 }
            found.append(Item(token: token(i, end), line: lineStart(i), ownLine: beginsLine(i), start: i, end: k))
            i = skip(k)
        }
        return found
    }

    /// The `{` of the file's root dictionary.
    var root: Int? {
        let i = skip(0)
        return i < bytes.count && bytes[i] == Self.openBrace ? i : nil
    }

    /// The `{` of `objects`.
    var objects: Int? {
        guard let root, let objects = entry("objects", in: root), bytes[objects.value] == Self.openBrace else { return nil }
        return objects.value
    }

    func entry(_ key: String, in open: Int) -> Entry? { entries(open).first { $0.key == key } }

    /// The object `id`'s entry in `objects`.
    func object(_ id: String) -> Entry? { objects.flatMap { entry(id, in: $0) } }

    /// The entry at `path` inside object `id`: `["attributes", "TargetAttributes"]`.
    func entry(_ path: [String], of id: String) -> Entry? {
        guard var current = object(id) else { return nil }
        for key in path {
            guard bytes[current.value] == Self.openBrace, let next = entry(key, in: current.value) else { return nil }
            current = next
        }
        return current
    }

    /// Whether the value starting at `index` is a dictionary, or an array.
    func isDictionary(_ index: Int) -> Bool { index < bytes.count && bytes[index] == Self.openBrace }
    func isArray(_ index: Int) -> Bool { index < bytes.count && bytes[index] == Self.openParen }

    /// Where `marker` first appears.
    func find(_ marker: String, from start: Int = 0) -> Int? {
        let needle = Array(marker.utf8)
        guard !needle.isEmpty, bytes.count >= needle.count, start <= bytes.count - needle.count else { return nil }
        var i = start
        while i <= bytes.count - needle.count {
            if bytes[i] == needle[0], Array(bytes[i..<(i + needle.count)]) == needle { return i }
            i += 1
        }
        return nil
    }

    /// One past the end of the line holding `index` (past its newline).
    func lineEnd(_ index: Int) -> Int {
        var i = index
        while i < bytes.count, bytes[i] != Self.newline { i += 1 }
        return min(i + 1, bytes.count)
    }

    // MARK: - Writing

    mutating func replace(_ range: Range<Int>, with text: String) { bytes.replaceSubrange(range, with: Array(text.utf8)) }

    mutating func insert(_ text: String, at index: Int) { bytes.insert(contentsOf: Array(text.utf8), at: index) }

    /// `text` as a pbxproj string: bare when Xcode writes it bare, quoted and escaped otherwise.
    static func quoted(_ text: String) -> String {
        if !text.isEmpty, text.utf8.allSatisfy({ ($0 >= 0x30 && $0 <= 0x39) || ($0 >= 0x41 && $0 <= 0x5A) || ($0 >= 0x61 && $0 <= 0x7A) || $0 == 0x5F || $0 == 0x2E || $0 == 0x2F }) {
            return text
        }
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t")
        return "\"" + escaped + "\""
    }

    /// Keys in the order Xcode writes them: isa first, then by their bytes.
    static func precedes(_ a: String, _ b: String) -> Bool {
        if a == "isa" { return b != "isa" }
        if b == "isa" { return false }
        return Array(a.utf8).lexicographicallyPrecedes(Array(b.utf8))
    }

    /// Sets `key` to `value` (written as the pbxproj says it) in the dictionary at `open`; false when it already was.
    @discardableResult
    mutating func set(_ key: String, to value: String, inDictionaryAt open: Int) -> Bool {
        let all = entries(open)
        if let found = all.first(where: { $0.key == key }) {
            let current = String(decoding: bytes[found.value..<found.valueEnd], as: UTF8.self)
            if current == value || (!value.hasPrefix("(") && token(found.value, found.valueEnd) == ProjectText(value).token(0, value.utf8.count)) { return false }
            replace(found.value..<found.valueEnd, with: value)
            return true
        }
        let line = Self.quoted(key) + " = " + value + ";"
        insertLine(line, among: all.map { ($0.key, $0.line, $0.ownLine) }, sortedBy: { Self.precedes(key, $0) }, closing: closing(open), open: open)
        return true
    }

    /// Adds `item` (with its `/* comment */`) to the end of the array at `open`; false when it is there already.
    @discardableResult
    mutating func append(_ item: String, comment: String?, toArrayAt open: Int) -> Bool {
        let all = items(open)
        if all.contains(where: { $0.token == item }) { return false }
        let line = item + (comment.map { " /* \($0) */" } ?? "") + ","
        insertLine(line, among: all.map { ($0.token, $0.line, $0.ownLine) }, sortedBy: { _ in false }, closing: closing(open), open: open)
        return true
    }

    /// The `(` of array `key` in the dictionary at `open`, made empty when it is not there.
    mutating func array(_ key: String, inDictionaryAt open: Int) -> Int {
        if let found = entry(key, in: open), isArray(found.value) { return found.value }
        let indent = entries(open).first.map { indentation($0.line) } ?? innerIndentation(open)
        set(key, to: "(\n" + indent + ")", inDictionaryAt: open)
        return entry(key, in: open)!.value
    }

    /// The `{` of dictionary `key` in the dictionary at `open`, made empty when it is not there.
    mutating func dictionary(_ key: String, inDictionaryAt open: Int) -> Int {
        if let found = entry(key, in: open), isDictionary(found.value) { return found.value }
        let indent = entries(open).first.map { indentation($0.line) } ?? innerIndentation(open)
        set(key, to: "{\n" + indent + "}", inDictionaryAt: open)
        return entry(key, in: open)!.value
    }

    /// Writes `line` into a bracket's lines: before the first sibling `sortedBy` puts after it, else last; indented
    /// as its siblings are, or one deeper than the bracket's own line.
    private mutating func insertLine(_ line: String, among siblings: [(key: String, line: Int, ownLine: Bool)],
                                     sortedBy after: (String) -> Bool, closing close: Int, open: Int) {
        if siblings.allSatisfy(\.ownLine), beginsLine(close) {
            let indent = siblings.first.map { indentation($0.line) } ?? innerIndentation(open)
            if let next = siblings.first(where: { after($0.key) }) {
                insert(indent + line + "\n", at: next.line)
            } else {
                insert(indent + line + "\n", at: lineStart(close))
            }
        } else {
            // A bracket written on one line: the new entry joins that line.
            let before = close > 0 && bytes[close - 1] == Self.space ? "" : " "
            insert(before + line + " ", at: close)
        }
    }

    /// Puts an object `entry` (its full text, lines ending in newlines) into its isa's section, in id order; makes
    /// the section, in order among the others, when the project has none.
    mutating func insertObject(_ entry: String, id: String, isa: String) {
        let begin = "/* Begin \(isa) section */", end = "/* End \(isa) section */"
        if let endIndex = find(end), let objects {
            let beginIndex = find(begin) ?? 0
            let inSection = entries(objects).filter { $0.line > beginIndex && $0.line < endIndex }
            if let next = inSection.first(where: { Array(id.utf8).lexicographicallyPrecedes(Array($0.key.utf8)) }) {
                insert(entry, at: next.line)
            } else {
                insert(entry, at: lineStart(endIndex))
            }
            return
        }
        var sections: [(isa: String, at: Int)] = []
        var cursor = 0
        while let at = find("/* Begin ", from: cursor) {
            let nameStart = at + 9
            if let close = find(" section */", from: nameStart) {
                sections.append((String(decoding: bytes[nameStart..<close], as: UTF8.self), at))
            }
            cursor = at + 9
        }
        if let next = sections.first(where: { Array(isa.utf8).lexicographicallyPrecedes(Array($0.isa.utf8)) }) {
            insert(begin + "\n" + entry + end + "\n\n", at: next.at)
        } else if let last = sections.last, let lastEnd = find("/* End \(last.isa) section */") {
            insert("\n" + begin + "\n" + entry + end + "\n", at: lineEnd(lastEnd))
        } else if let objects {
            insert(entry, at: lineStart(closing(objects)))
        }
    }
}
