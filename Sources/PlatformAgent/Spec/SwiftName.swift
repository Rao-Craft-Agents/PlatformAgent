//  WHAT: What Swift accepts as a name, and how a title is said as one: keywords escaped, words joined in
//        lowerCamelCase for a case name.

import Foundation

enum SwiftName {
    static let keywords: Set<String> = ["associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
                                        "inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public",
                                        "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue",
                                        "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw",
                                        "switch", "where", "while", "as", "Any", "false", "is", "nil", "self", "Self", "super", "throws", "true",
                                        "try", "some", "any"]

    static func isTypeName(_ text: String) -> Bool {
        text.range(of: #"^[A-Z][A-Za-z0-9]*$"#, options: .regularExpression) != nil
    }

    /// A member name as code writes it: a keyword in backticks.
    static func member(_ name: String) -> String { keywords.contains(name) ? "`\(name)`" : name }

    /// `Mark All Read` → `markAllRead`; `Show 2-Up` → `show2Up`; nil when nothing in it is a letter or digit.
    static func camel(_ title: String) -> String? {
        let words = title.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard let first = words.first else { return nil }
        let head = first.prefix { $0.isUppercase }.count == first.count ? first.lowercased() : first.prefix(1).lowercased() + first.dropFirst()
        var name = head + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        name = name.filter { $0.isASCII }
        guard let lead = name.first else { return nil }
        if lead.isNumber { name = "command" + name }
        return name
    }

    /// `SetInstance` → `Set Instance`.
    static func words(_ name: String) -> String {
        var out = "", previous: Character?
        for character in name {
            if character.isUppercase, let p = previous, p.isLowercase || p.isNumber { out.append(" ") }
            out.append(character)
            previous = character
        }
        return out
    }
}
