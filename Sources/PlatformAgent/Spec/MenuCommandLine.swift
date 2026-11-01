//  WHAT: A command line, how a call names one menu command of the macOS app:
//
//            New Recipe ⌘N
//            Refresh ⌘R
//            Kitchen > Start Timer ⇧⌘T
//            View > Toggle Sidebar ⌃⌘S
//
//        An optional menu and `>`, the title as the menu shows it, then an optional shortcut. With no menu, the
//        title's first word places it: New, Open, Save, Import, Export, Print → File; Find, Search, Select → Edit;
//        Show, Hide, Toggle, Refresh, Reload, Zoom, Sort, Filter → View; Go, Back, Forward, Next, Previous → Go.
//  PIN:  A COMMAND WITH NO HOME IS REFUSED. Where `Start Timer` belongs is the app's to say; a guess would put it
//        in a menu the person never looks in.

import Foundation

enum MenuCommandLine {
    static func parse(_ line: String) throws -> MenuCommand {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PlatformError.refused(["a command line is empty"]) }
        var menu: String?
        if let bracket = text.firstIndex(of: ">") {
            menu = String(text[..<bracket]).trimmingCharacters(in: .whitespaces)
            text = String(text[text.index(after: bracket)...]).trimmingCharacters(in: .whitespaces)
        }
        var shortcut: Shortcut?
        if let start = text.firstIndex(where: { "⌘⌃⌥⇧".contains($0) }) {
            let written = String(text[start...])
            guard let read = Shortcut.parse(written) else {
                throw PlatformError.refused(["`\(written)` in `\(line)` is not a shortcut: write it as the menu shows it, like ⇧⌘K"])
            }
            shortcut = read
            text = String(text[..<start]).trimmingCharacters(in: .whitespaces)
        } else if let last = text.split(separator: " ").last, text.contains(" "), last.contains(where: { $0 == "+" || $0 == "-" }) {
            // `cmd+shift+k` is a shortcut; `2-Up` is part of the title.
            if let read = Shortcut.parse(String(last)) {
                shortcut = read
                text = String(text.dropLast(last.count)).trimmingCharacters(in: .whitespaces)
            } else if last.contains("+") {
                throw PlatformError.refused(["`\(last)` in `\(line)` is not a shortcut: write it as the menu shows it, like ⇧⌘K"])
            }
        }
        let title = text.trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        guard let name = SwiftName.camel(title), !title.contains("("), !title.contains(")") else {
            throw PlatformError.refused(["`\(line)` names no command: write its title as the menu shows it, like `New Recipe ⌘N`"])
        }
        var reasons: [String] = []
        var placed = ""
        if let menu, !menu.isEmpty {
            if let standard = MenuCommand.standard.first(where: { $0.lowercased() == menu.lowercased() }) { placed = standard }
            else if menu.range(of: #"^[A-Za-z][A-Za-z0-9 &'-]{0,23}$"#, options: .regularExpression) != nil { placed = menu }
            else { reasons.append("`\(menu)` is not a menu name: say File, Edit, View, Window, Help, App or the app's own menu, like `Kitchen`") }
        } else if let inferred = inferredMenu(title) {
            placed = inferred
        } else {
            reasons.append("`\(line)` names no menu: say where it goes, like `Kitchen > \(line.trimmingCharacters(in: .whitespaces))` (File, Edit, View, Window, Help, App, or a menu of the app's own)")
        }
        if let shortcut, let owner = Shortcut.reserved[shortcut.symbol] {
            reasons.append("\(shortcut.symbol) is \(owner)'s in every Mac app: give \(title) another shortcut")
        }
        guard reasons.isEmpty else { throw PlatformError.refused(reasons) }
        return MenuCommand(title: title, menu: placed, shortcut: shortcut, name: name)
    }

    /// The menu a title's first word places it in; nil when the word says nothing of where.
    static func inferredMenu(_ title: String) -> String? {
        let first = title.split(separator: " ").first.map { $0.lowercased() } ?? ""
        if title.lowercased().hasSuffix(" help") || first == "help" { return "Help" }
        switch first {
        case "new", "open", "close", "save", "import", "export", "print", "duplicate", "share": return "File"
        case "find", "search", "select", "copy", "paste", "delete", "rename", "undo", "redo": return "Edit"
        case "show", "hide", "toggle", "refresh", "reload", "zoom", "enter", "exit", "sort", "filter": return "View"
        case "go", "back", "forward", "next", "previous": return "Go"
        case "minimize", "bring": return "Window"
        default: return nil
        }
    }
}
