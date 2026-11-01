import Foundation

/// One app extension of the iOS app, read off an extension line.
struct AppExtension: Equatable, Sendable {
    enum Kind: String, Sendable, CaseIterable {
        /// An Action: a row in the share sheet's actions that hands the item to the app.
        case action
        /// A Share extension: the app in the share sheet's row of apps.
        case share

        /// The project folder its extensions live under: `Action`, `Share`.
        var folder: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
        /// The extension point the system offers it at.
        var point: String { self == .action ? "com.apple.ui-services" : "com.apple.share-services" }
    }

    /// What it takes from the share sheet.
    enum Accepts: String, Sendable, CaseIterable, Comparable {
        case url, image, text

        static func < (a: Accepts, b: Accepts) -> Bool { allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)! }
    }

    var kind: Kind
    /// `SetInstance`: the folder, and the target with its kind (`SetInstanceAction`).
    var name: String
    /// What the share sheet shows: `Save to Recipes`.
    var title: String
    var accepts: [Accepts]

    /// The target and its product: `SaveRecipeAction`.
    var target: String { name + kind.folder }
    /// Where its files live, relative to the project: `Action/SaveRecipe`.
    var folder: String { kind.folder + "/" + name }
    /// Its principal view controller: `SaveRecipeViewController`.
    var controller: String { name + "ViewController" }
    /// As a line again.
    var line: String { "\(kind.rawValue) \(name) \"\(title)\" accepts \(accepts.map(\.rawValue).joined(separator: ","))" }
}
