//  WHAT: The macOS app's menu commands: `Shared/Utility/AppCommand.swift` (one case a command, each with the name
//        it is posted under), `Shared/Extensions/View+OnAppCommand.swift` (`.onAppCommand(.newRecipe) { }`), and
//        `macOS/AppCommands.swift` (the `Commands` the app's scene adds: each menu's buttons and shortcuts).
//  PIN:  A COMMAND IS ANSWERED WHERE ITS STATE IS. The menu only posts; the view or service that owns what the
//        command changes answers it, so the menu bar holds no state of its own.
//  PIN:  READ BACK, NOT FORGOTTEN. Each case's doc comment says the command as a line says it, so a later call
//        adds to the menu instead of replacing it.
//  PIN:  ⌘N TAKES NEW WINDOW'S PLACE. A File command on ⌘N replaces the File menu's New Window, which held it;
//        otherwise File commands follow it.

import Foundation

enum CommandFiles {
    static let typePath = "Shared/Utility/AppCommand.swift"
    static let modifierPath = "Shared/Extensions/View+OnAppCommand.swift"
    static let menuPath = "macOS/AppCommands.swift"

    /// Whether `text` is an AppCommands.swift this agent wrote.
    static func isOurs(_ text: String) -> Bool { text.contains("/// The app's own menu commands") }

    /// The commands an AppCommand.swift this agent wrote holds, in order.
    static func commands(in text: String) -> [MenuCommand] {
        let pattern = #"///\s(.+?)(?:\s\(([^()]+)\))?,\sin the\s(.+?)\smenu\.\n\s*case\s+`?(\w+)`?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            func group(_ index: Int) -> String? { Range(match.range(at: index), in: text).map { String(text[$0]) } }
            guard let title = group(1), let menu = group(3) else { return nil }
            let line = "\(menu) > \(title)" + (group(2).map { " " + $0 } ?? "")
            return try? MenuCommandLine.parse(line)
        }
    }

    static func type(_ commands: [MenuCommand]) -> String {
        var lines = [
            "import Foundation",
            "",
            "/// The app's menu commands. The menu bar posts one when it is chosen, and the view or service that owns what",
            "/// it changes answers it with `.onAppCommand(.\(commands.first?.name ?? "command")) { }`.",
            "enum AppCommand: String, CaseIterable, Sendable {",
        ]
        for command in commands {
            let shortcut = command.shortcut.map { " (\($0.symbol))" } ?? ""
            lines.append("    /// \(command.title)\(shortcut), in the \(command.menu) menu.")
            lines.append("    case \(SwiftName.member(command.name))")
        }
        lines += [
            "",
            "    /// The name the command is posted under.",
            "    var notification: Notification.Name {",
            "        Notification.Name(\"AppCommand.\" + rawValue)",
            "    }",
            "",
            "    /// Tells the views that answer this command.",
            "    func post() {",
            "        NotificationCenter.default.post(name: notification, object: nil)",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    static let modifier = #"""
        import SwiftUI

        extension View {
            /// Runs `action` when the menu command `command` is chosen.
            func onAppCommand(_ command: AppCommand, perform action: @escaping () -> Void) -> some View {
                onReceive(NotificationCenter.default.publisher(for: command.notification)) { _ in
                    action()
                }
            }
        }

        """#

    /// Whether the File menu's commands replace New Window: one of them takes ⌘N.
    static func replacesNewWindow(_ commands: [MenuCommand]) -> Bool {
        commands.contains { $0.menu == "File" && $0.shortcut == Shortcut(key: "n", modifiers: [.command]) }
    }

    static func menu(_ commands: [MenuCommand]) -> String {
        var lines = [
            "import SwiftUI",
            "",
            "/// The app's own menu commands: each button posts its `AppCommand` for the views that answer it.",
            "struct AppCommands: Commands {",
            "    var body: some Commands {",
        ]
        let placements: [(menu: String, opening: String)] = [
            ("App", "CommandGroup(after: .appInfo)"),
            ("File", replacesNewWindow(commands) ? "CommandGroup(replacing: .newItem)" : "CommandGroup(after: .newItem)"),
            ("Edit", "CommandGroup(after: .pasteboard)"),
            ("View", "CommandGroup(after: .toolbar)"),
            ("Window", "CommandGroup(after: .windowArrangement)"),
            ("Help", "CommandGroup(after: .help)"),
        ]
        var menus: [(opening: String, commands: [MenuCommand])] = []
        for placement in placements {
            let held = commands.filter { $0.menu == placement.menu }
            if !held.isEmpty { menus.append((placement.opening, held)) }
        }
        var own: [String] = []
        for command in commands where !MenuCommand.standard.contains(command.menu) && !own.contains(command.menu) { own.append(command.menu) }
        for name in own {
            menus.append(("CommandMenu(\"\(name.replacingOccurrences(of: "\"", with: "\\\""))\")", commands.filter { $0.menu == name }))
        }
        for (index, menu) in menus.enumerated() {
            if index > 0 { lines.append("") }
            lines.append("        \(menu.opening) {")
            let chunks = stride(from: 0, to: menu.commands.count, by: 10).map { Array(menu.commands[$0..<min($0 + 10, menu.commands.count)]) }
            for chunk in chunks {
                let indent = chunks.count > 1 ? "                " : "            "
                if chunks.count > 1 { lines.append("            Group {") }
                for command in chunk {
                    let title = command.title.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    lines.append("\(indent)Button(\"\(title)\") {")
                    lines.append("\(indent)    AppCommand.\(command.name).post()")
                    lines.append("\(indent)}" + (command.shortcut.map { "\n\(indent)\($0.swift)" } ?? ""))
                }
                if chunks.count > 1 { lines.append("            }") }
            }
            lines.append("        }")
        }
        lines += ["    }", "}"]
        return lines.joined(separator: "\n") + "\n"
    }
}
