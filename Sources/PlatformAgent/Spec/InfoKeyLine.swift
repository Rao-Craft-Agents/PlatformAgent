//  WHAT: A key line, how a call names one Info.plist key:
//
//            camera: "takes photos of the dishes you cook"
//            category: lifestyle
//            queries: maps, comgooglemaps
//            UIBackgroundModes: [fetch, remote-notification]
//
//        A word this agent knows (InfoVocabulary) or an Info.plist key by its own name, a colon, then the value:
//        a usage string, a category, yes or no, or a list split by commas.
//  PIN:  A WHY IS A SENTENCE. A usage string is what the system shows a person asking for a permission, so it is
//        capitalised and ends in a period whatever the line wrote; the words stay the line's.

import Foundation

enum InfoKeyLine {
    static func parse(_ line: String) throws -> InfoKey {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = LineSplit.firstTop(text, ":") else {
            throw PlatformError.refused(["`\(line)` is not a key line: write `camera: \"why the app asks\"`"])
        }
        let name = String(text[..<colon]).trimmingCharacters(in: CharacterSet(charactersIn: " \"`"))
        let raw = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { throw PlatformError.refused(["`\(line)` gives \(name) no value"]) }

        if let word = InfoVocabulary.words[InfoVocabulary.fold(name)] ?? InfoVocabulary.words.values.first(where: { $0.key == name }) {
            return InfoKey(key: word.key, value: try value(raw, kind: word.kind, line: line),
                           platforms: word.platforms, isSetting: InfoVocabulary.settings.contains(word.key) && word.kind != .list)
        }
        guard name.range(of: #"^[A-Z][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil else {
            throw PlatformError.refused(["`\(name)` is not an Info key this agent knows: say one of "
                + InfoVocabulary.named.joined(separator: ", ") + ", or an Info.plist key by its own name (NSFaceIDUsageDescription)"])
        }
        // An Info.plist key by its own name: a list in brackets, yes or no, else text (a sentence when it says why).
        let kind: InfoVocabulary.Kind
        if raw.hasPrefix("["), raw.hasSuffix("]") { kind = .list }
        else if boolean(raw) != nil, !raw.hasPrefix("\"") { kind = .boolean }
        else { kind = name.hasSuffix("UsageDescription") ? .usage : .text }
        let isSetting = InfoVocabulary.settings.contains(name) && kind != .list
        return InfoKey(key: name, value: try value(raw, kind: kind, line: line), platforms: InfoVocabulary.both, isSetting: isSetting)
    }

    static func value(_ raw: String, kind: InfoVocabulary.Kind, line: String) throws -> InfoKey.Value {
        switch kind {
        case .usage:
            let text = unquoted(raw)
            guard !text.isEmpty else { throw PlatformError.refused(["`\(line)` says no reason"]) }
            return .string(sentence(text))
        case .text:
            return .string(unquoted(raw))
        case .category:
            let folded = unquoted(raw).lowercased()
                .replacingOccurrences(of: "public.app-category.", with: "")
                .replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "_", with: "-")
            guard InfoVocabulary.categories.contains(folded) else {
                throw PlatformError.refused(["`\(unquoted(raw))` is not an App Store category: say one of "
                    + InfoVocabulary.categories.prefix(21).joined(separator: ", ")])
            }
            return .string("public.app-category." + folded)
        case .boolean:
            guard let flag = boolean(unquoted(raw)) else { throw PlatformError.refused(["`\(line)` takes yes or no"]) }
            return .boolean(flag)
        case .list:
            var body = raw
            if body.hasPrefix("["), body.hasSuffix("]") { body = String(body.dropFirst().dropLast()) }
            let items = LineSplit.top(body, on: ",").map(unquoted).filter { !$0.isEmpty }
            guard !items.isEmpty else { throw PlatformError.refused(["`\(line)` lists nothing"]) }
            return .list(items)
        }
    }

    static func boolean(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "yes", "true": return true
        case "no", "false": return false
        default: return nil
        }
    }

    static func unquoted(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") { trimmed = String(trimmed.dropFirst().dropLast()) }
        return trimmed.replacingOccurrences(of: "\\\"", with: "\"").trimmingCharacters(in: .whitespaces)
    }

    /// `takes photos of dishes` → `Takes photos of dishes.`
    static func sentence(_ text: String) -> String {
        guard let first = text.first else { return text }
        let capped = first.uppercased() + text.dropFirst()
        return [".", "!", "?"].contains(where: capped.hasSuffix) ? capped : capped + "."
    }
}
