//  WHAT: A menu command's keyboard shortcut: its modifiers and key, read from a line as a menu shows it (`⇧⌘K`,
//        `⌃⌘S`, `⌘↩`) or as it is typed (`cmd+shift+k`), and said back both ways: the symbols for the doc
//        comment and the line, `.keyboardShortcut(…)` for SwiftUI.
//  PIN:  THE SYSTEM'S SHORTCUTS ARE NOT OFFERED. ⌘Q, ⌘W, ⌘H, ⌘M, ⌘, and the edit shortcuts belong to menus every
//        Mac app has; a command that takes one is refused, naming whose it is.

import Foundation

struct Shortcut: Equatable, Hashable, Sendable {
    /// In the order a menu shows them: ⌃ ⌥ ⇧ ⌘.
    enum Modifier: String, CaseIterable, Sendable {
        case control, option, shift, command

        var symbol: String {
            switch self {
            case .control: return "⌃"
            case .option: return "⌥"
            case .shift: return "⇧"
            case .command: return "⌘"
            }
        }
    }

    /// One character (`k`, `1`, `,`) or a named key (`return`, `upArrow`).
    var key: String
    var modifiers: Set<Modifier>

    /// The named keys: SwiftUI's `KeyEquivalent` name, its symbol, and the words a line may say it with.
    static let named: [(name: String, symbol: String, words: [String])] = [
        ("return", "↩", ["return", "enter", "↩", "⏎"]), ("delete", "⌫", ["delete", "backspace", "⌫"]),
        ("deleteForward", "⌦", ["forwarddelete", "deleteforward", "⌦"]), ("escape", "⎋", ["escape", "esc", "⎋"]),
        ("tab", "⇥", ["tab", "⇥"]), ("space", "Space", ["space", "␣"]), ("upArrow", "↑", ["up", "uparrow", "↑"]),
        ("downArrow", "↓", ["down", "downarrow", "↓"]), ("leftArrow", "←", ["left", "leftarrow", "←"]),
        ("rightArrow", "→", ["right", "rightarrow", "→"]), ("home", "↖", ["home", "↖"]), ("end", "↘", ["end", "↘"]),
        ("pageUp", "⇞", ["pageup", "⇞"]), ("pageDown", "⇟", ["pagedown", "⇟"]), ("clear", "Clear", ["clear"]),
    ]

    /// Shortcuts every Mac app's own menus hold, by symbol, with whose they are.
    static let reserved: [String: String] = [
        "⌘Q": "Quit", "⌘W": "Close", "⌘H": "Hide", "⌥⌘H": "Hide Others", "⌘M": "Minimize", "⌘,": "Settings", "⌘C": "Copy",
        "⌘V": "Paste", "⌘X": "Cut", "⌘A": "Select All", "⌘Z": "Undo", "⇧⌘Z": "Redo", "⌃⌘F": "Enter Full Screen",
        "⌘`": "the window cycle", "⇧⌘/": "Help",
    ]

    /// The characters a one-character key may be, beside letters and digits.
    static let punctuation: Set<Character> = [",", ".", "/", ";", "'", "[", "]", "\\", "-", "=", "`"]

    /// Reads `⇧⌘K`, `⌘↩`, `⌥⌘Space` or `cmd+shift+k`; nil when `text` is not a shortcut.
    static func parse(_ text: String) -> Shortcut? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var modifiers: Set<Modifier> = []
        var rest = Substring(trimmed)
        if let first = trimmed.first, Modifier.allCases.contains(where: { $0.symbol == String(first) }) {
            while let next = rest.first, let modifier = Modifier.allCases.first(where: { $0.symbol == String(next) }) {
                modifiers.insert(modifier); rest = rest.dropFirst()
            }
        } else {
            let parts = trimmed.split(whereSeparator: { $0 == "+" || $0 == "-" }).map { $0.lowercased() }
            guard parts.count >= 2 else { return nil }
            for part in parts.dropLast() {
                switch part {
                case "cmd", "command": modifiers.insert(.command)
                case "ctrl", "control": modifiers.insert(.control)
                case "opt", "option", "alt": modifiers.insert(.option)
                case "shift": modifiers.insert(.shift)
                default: return nil
                }
            }
            rest = Substring(parts.last!)
        }
        guard let key = key(String(rest).trimmingCharacters(in: .whitespaces)) else { return nil }
        return Shortcut(key: key, modifiers: modifiers)
    }

    /// The key a word names: a named key's SwiftUI name, or one lowercase character.
    static func key(_ word: String) -> String? {
        let folded = word.lowercased()
        if let named = named.first(where: { $0.words.contains(folded) || $0.symbol.lowercased() == folded }) { return named.name }
        guard word.count == 1, let character = folded.first else { return nil }
        return character.isLetter && character.isASCII || character.isNumber && character.isASCII || punctuation.contains(character) ? folded : nil
    }

    /// As a menu shows it: `⇧⌘K`.
    var symbol: String {
        let mods = Modifier.allCases.filter(modifiers.contains).map(\.symbol).joined()
        return mods + (Self.named.first { $0.name == key }?.symbol ?? key.uppercased())
    }

    /// As SwiftUI writes it: `.keyboardShortcut("k", modifiers: [.command, .shift])`.
    var swift: String {
        let keyText: String
        if Self.named.contains(where: { $0.name == key }) { keyText = "." + key }
        else { keyText = "\"" + (key == "\\" ? "\\\\" : key) + "\"" }
        if modifiers == [.command] { return ".keyboardShortcut(\(keyText))" }
        let order: [Modifier] = [.command, .shift, .option, .control]
        let list = order.filter(modifiers.contains).map { "." + $0.rawValue }
        if list.count == 1 { return ".keyboardShortcut(\(keyText), modifiers: \(list[0]))" }
        return ".keyboardShortcut(\(keyText), modifiers: [\(list.joined(separator: ", "))])"
    }
}
