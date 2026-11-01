//  WHAT: An extension line, how a call names one app extension of the iOS app:
//
//            action SaveRecipe "Save to Recipes" accepts url,image
//            share ShareToKitchen "Kitchen" accepts text, image
//
//        `action` or `share`, the name (UpperCamelCase: its folder `Action/SaveRecipe`, its target
//        `SaveRecipeAction`), the title the share sheet shows in quotes (the name's words when left out), and
//        what it accepts: url, image, text (url when left out).

import Foundation

enum ExtensionLine {
    static func parse(_ line: String) throws -> AppExtension {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var title: String?
        if let open = text.firstIndex(of: "\""), let close = text[text.index(after: open)...].firstIndex(of: "\"") {
            title = String(text[text.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            text = String(text[..<open]) + " " + String(text[text.index(after: close)...])
        }
        let words = text.split(separator: " ").map(String.init)
        guard let first = words.first, let kind = AppExtension.Kind(rawValue: first.lowercased()) else {
            throw PlatformError.refused(["`\(line)` is not an extension line: start it with action or share, like `action SaveRecipe \"Save to Recipes\" accepts url`"])
        }
        guard words.count >= 2, SwiftName.isTypeName(words[1]) else {
            let said = words.count >= 2 ? words[1] : ""
            throw PlatformError.refused(["`\(said)` in `\(line)` is not an extension name: say one UpperCamelCase word, like SaveRecipe"])
        }
        let name = words[1]
        var accepts: [AppExtension.Accepts] = []
        let rest = words.dropFirst(2)
        if let keyword = rest.first {
            guard keyword.lowercased() == "accepts" else {
                throw PlatformError.refused(["`\(line)` has `\(keyword)` where `accepts` goes: write `accepts url,image`"])
            }
            let listed = rest.dropFirst().joined(separator: " ").split(whereSeparator: { $0 == "," || $0 == " " }).map { $0.lowercased() }
            for word in listed {
                guard let accepted = accepted(word) else {
                    throw PlatformError.refused(["`\(word)` in `\(line)` is not something an extension accepts: say url, image or text"])
                }
                if !accepts.contains(accepted) { accepts.append(accepted) }
            }
            if accepts.isEmpty { throw PlatformError.refused(["`\(line)` accepts nothing: say url, image or text"]) }
        }
        if accepts.isEmpty { accepts = [.url] }
        let shown = title.flatMap { $0.isEmpty ? nil : $0 } ?? SwiftName.words(name)
        return AppExtension(kind: kind, name: name, title: shown, accepts: accepts.sorted())
    }

    static func accepted(_ word: String) -> AppExtension.Accepts? {
        switch word {
        case "url", "urls", "link", "links", "web", "webpage": return .url
        case "image", "images", "photo", "photos", "picture", "pictures": return .image
        case "text", "texts", "string", "plaintext": return .text
        default: return nil
        }
    }
}
