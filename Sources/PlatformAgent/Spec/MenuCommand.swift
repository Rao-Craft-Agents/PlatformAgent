import Foundation

/// One menu command of the macOS app, read off a command line.
struct MenuCommand: Equatable, Sendable {
    /// As the menu shows it: `New Post`.
    var title: String
    /// `File`, `Edit`, `View`, `Window`, `Help`, `App`, or a menu of the app's own (`Feed`).
    var menu: String
    var shortcut: Shortcut?
    /// The `AppCommand` case: `newPost`.
    var name: String

    /// The menus every Mac app has, where a command joins the system's own items.
    static let standard = ["File", "Edit", "View", "Window", "Help", "App"]

    /// As a command line again: `File > New Post ⌘N`.
    var line: String { "\(menu) > \(title)" + (shortcut.map { " " + $0.symbol } ?? "") }
}
