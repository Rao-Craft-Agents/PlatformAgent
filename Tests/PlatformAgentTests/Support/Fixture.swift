import Foundation
@testable import PlatformAgent

enum Fixture {
    /// A folder of its own for one test, removed with the process's temporary files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("platform-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A folder holding the recipe app's project, as granite makes it.
    static func project(name: String = "Recipes") throws -> URL {
        let folder = try folder()
        try FixtureProject.make(in: folder, name: name)
        return folder
    }

    /// A recipe app's platform layer: what the package is held to writing well.
    static let keys = [
        #"camera: "takes photos of the dishes you cook""#,
        #"photos: "picks a photo for a recipe""#,
        #"localNetwork: "finds the kitchen display on your network""#,
        #"faceID: "unlocks your private recipes""#,
        "category: lifestyle",
        "queries: maps, comgooglemaps",
        "bonjour: _recipes._tcp",
    ]
    static let commands = ["New Recipe ⌘N", "Refresh ⌘R", "Kitchen > Start Timer ⇧⌘T", "Toggle Sidebar ⌃⌘S"]
    static let extensions = [#"action SaveRecipe "Save to Recipes" accepts url,image"#, #"share ShareToKitchen "Kitchen" accepts text, image"#]

    /// Every field at once.
    static func everything(_ directory: URL) -> PlatformAgent.Input {
        PlatformAgent.Input(keys: keys, schemes: ["recipes"], ats: .domains, atsDomains: ["kitchen.local", "https://pantry.example.com/api"],
                            groups: ["group.com.example.recipes"], keychain: ["com.example.recipes.shared"],
                            sandbox: PlatformSandbox.allCases, commands: commands, extensions: extensions,
                            delegate: PlatformDelegate.allCases, directory: directory.path)
    }

    /// A call made the way a test makes one: no host, no notes.
    @discardableResult
    static func call(_ input: PlatformAgent.Input) throws -> PlatformResult {
        try PlatformAgent.write(input, note: { _ in }, yield: { _ in })
    }

    static func text(_ folder: URL, _ path: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(path), encoding: .utf8)
    }

    static func plist(_ folder: URL, _ path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: folder.appendingPathComponent(path))
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:]
    }

    /// The project file of the fixture.
    static func pbxproj(_ folder: URL, name: String = "Recipes") throws -> String {
        try text(folder, "\(name).xcodeproj/project.pbxproj")
    }
}
