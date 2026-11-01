import XCTest
@testable import PlatformAgent

/// The lines a model writes, read: every form the guide promises, and a reason for every line refused.
final class LineTests: XCTestCase {
    private func refused(_ make: () throws -> Any, _ reason: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try make(), file: file, line: line) { error in
            XCTAssertTrue("\(error)".contains(reason), "\(error)", file: file, line: line)
        }
    }

    func testKeyLines() throws {
        let camera = try InfoKeyLine.parse(#"camera: "takes photos of the dishes you cook""#)
        XCTAssertEqual(camera, InfoKey(key: "NSCameraUsageDescription", value: .string("Takes photos of the dishes you cook."),
                                       platforms: [.iOS, .macOS], isSetting: true), "a why is a sentence")
        XCTAssertEqual(try InfoKeyLine.parse("Local Network: finds the kitchen display").key, "NSLocalNetworkUsageDescription")
        XCTAssertEqual(try InfoKeyLine.parse("faceID: unlocks recipes").platforms, [.iOS])
        XCTAssertEqual(try InfoKeyLine.parse("category: Social Networking").value, .string("public.app-category.social-networking"))
        XCTAssertEqual(try InfoKeyLine.parse("category: public.app-category.lifestyle").value, .string("public.app-category.lifestyle"))
        let queries = try InfoKeyLine.parse("queries: maps, comgooglemaps")
        XCTAssertEqual(queries.value, .list(["maps", "comgooglemaps"]))
        XCTAssertFalse(queries.isSetting, "a list goes in the Info.plist")
        XCTAssertEqual(try InfoKeyLine.parse("encryption: no").value, .boolean(false))
        let modes = try InfoKeyLine.parse("UIBackgroundModes: [fetch, remote-notification]")
        XCTAssertEqual(modes.value, .list(["fetch", "remote-notification"]))
        XCTAssertFalse(modes.isSetting)
        let siri = try InfoKeyLine.parse(#"NSSiriUsageDescription: "reads recipes aloud""#)
        XCTAssertTrue(siri.isSetting, "a key Xcode has a setting for is a setting")
        XCTAssertEqual(siri.value, .string("Reads recipes aloud."))
        XCTAssertEqual(try InfoKeyLine.parse("NSFaceIDUsageDescription: unlocks").platforms, [.iOS], "a known key keeps its platforms")
        XCTAssertFalse(try InfoKeyLine.parse("CustomKey: some text").isSetting)

        refused({ try InfoKeyLine.parse("flashlight: lights the stove") }, "not an Info key this agent knows")
        refused({ try InfoKeyLine.parse("category: food") }, "not an App Store category")
        refused({ try InfoKeyLine.parse("camera takes photos") }, "not a key line")
        refused({ try InfoKeyLine.parse("camera: ") }, "no value")
        refused({ try InfoKeyLine.parse("encryption: maybe") }, "takes yes or no")
    }

    func testShortcuts() throws {
        let timer = try XCTUnwrap(Shortcut.parse("⇧⌘T"))
        XCTAssertEqual(timer, Shortcut(key: "t", modifiers: [.shift, .command]))
        XCTAssertEqual(timer.symbol, "⇧⌘T")
        XCTAssertEqual(timer.swift, ".keyboardShortcut(\"t\", modifiers: [.command, .shift])")
        XCTAssertEqual(Shortcut.parse("cmd+shift+t"), timer, "typed as it is pressed")
        XCTAssertEqual(Shortcut.parse("⌘N")?.swift, ".keyboardShortcut(\"n\")")
        XCTAssertEqual(Shortcut.parse("⌘↩")?.swift, ".keyboardShortcut(.return)")
        XCTAssertEqual(Shortcut.parse("⌥⌘Space")?.symbol, "⌥⌘Space")
        XCTAssertEqual(Shortcut.parse("⌃⌘S")?.swift, ".keyboardShortcut(\"s\", modifiers: [.command, .control])")
        XCTAssertEqual(Shortcut.parse("⌥⌘\\")?.swift, ".keyboardShortcut(\"\\\\\", modifiers: [.command, .option])")
        XCTAssertNil(Shortcut.parse("⌘("), "not a key a menu can show")
        XCTAssertNil(Shortcut.parse("2-Up"))
    }

    func testCommandLines() throws {
        let new = try MenuCommandLine.parse("New Recipe ⌘N")
        XCTAssertEqual(new, MenuCommand(title: "New Recipe", menu: "File", shortcut: Shortcut(key: "n", modifiers: [.command]), name: "newRecipe"))
        XCTAssertEqual(try MenuCommandLine.parse("Kitchen > Start Timer ⇧⌘T").menu, "Kitchen")
        XCTAssertEqual(try MenuCommandLine.parse("view > Show Grocery List").menu, "View", "a system menu by any case")
        let refresh = try MenuCommandLine.parse("Refresh")
        XCTAssertEqual(refresh.menu, "View")
        XCTAssertNil(refresh.shortcut)
        XCTAssertEqual(try MenuCommandLine.parse("Find Recipe cmd+f").shortcut, Shortcut(key: "f", modifiers: [.command]))
        let twoUp = try MenuCommandLine.parse("Show 2-Up")
        XCTAssertEqual(twoUp.title, "Show 2-Up")
        XCTAssertEqual(twoUp.name, "show2Up")
        XCTAssertEqual(try MenuCommandLine.parse("Next Step ⌘]").menu, "Go")
        XCTAssertEqual(new.line, "File > New Recipe ⌘N")
        XCTAssertEqual(try MenuCommandLine.parse(new.line), new, "a command said as a line reads back as itself")

        refused({ try MenuCommandLine.parse("Start Timer ⇧⌘T") }, "names no menu")
        refused({ try MenuCommandLine.parse("Quit Cooking ⌘Q") }, "⌘Q is Quit's")
        refused({ try MenuCommandLine.parse("File > Save Copy ⌘(") }, "is not a shortcut")
        refused({ try MenuCommandLine.parse("File > ⌘S") }, "names no command")
        refused({ try MenuCommandLine.parse("Kitchen! > Start ⌘T") }, "not a menu name")
    }

    func testExtensionLines() throws {
        let save = try ExtensionLine.parse(#"action SaveRecipe "Save to Recipes" accepts url,image"#)
        XCTAssertEqual(save, AppExtension(kind: .action, name: "SaveRecipe", title: "Save to Recipes", accepts: [.url, .image]))
        XCTAssertEqual(save.target, "SaveRecipeAction")
        XCTAssertEqual(save.folder, "Action/SaveRecipe")
        XCTAssertEqual(save.controller, "SaveRecipeViewController")
        let share = try ExtensionLine.parse("Share ShareToKitchen accepts photos, Text, links")
        XCTAssertEqual(share.title, "Share To Kitchen", "the name's words when no title is given")
        XCTAssertEqual(share.accepts, [.url, .image, .text])
        XCTAssertEqual(share.kind.point, "com.apple.share-services")
        XCTAssertEqual(try ExtensionLine.parse("action Clip").accepts, [.url], "a link when it says nothing")

        refused({ try ExtensionLine.parse("widget Clip accepts url") }, "start it with action or share")
        refused({ try ExtensionLine.parse("action save-recipe accepts url") }, "not an extension name")
        refused({ try ExtensionLine.parse("action Clip accepts video") }, "is not something an extension accepts")
        refused({ try ExtensionLine.parse("action Clip takes url") }, "where `accepts` goes")
    }

    func testTheRequestIsMadeCanonicalAndSaysEveryProblem() {
        let request = PlatformRequest(PlatformAgent.Input(
            schemes: ["recipes://", "Recipes", "kitchen"], atsDomains: ["https://Pantry.Example.com/api", "kitchen.local:8080"],
            groups: ["com.example.recipes", "group.com.example.recipes"], keychain: ["com.example.recipes.shared"],
            sandbox: [.network, .network], delegate: [.urls, .urls]))
        XCTAssertEqual(request.reasons, [])
        XCTAssertEqual(request.schemes, ["recipes", "kitchen"], "a scheme once, whatever its case or `://`")
        XCTAssertEqual(request.ats, .domains, "hosts given mean domains")
        XCTAssertEqual(request.atsDomains, ["pantry.example.com", "kitchen.local"])
        XCTAssertEqual(request.groups, ["group.com.example.recipes"])
        XCTAssertEqual(request.keychain, ["$(AppIdentifierPrefix)com.example.recipes.shared"])
        XCTAssertEqual(request.sandbox, [.network])
        XCTAssertEqual(request.delegate, [.urls])

        let bad = PlatformRequest(PlatformAgent.Input(
            keys: ["flashlight: on", "camera: x", "camera: y"], schemes: ["9lives"], ats: .default, atsDomains: ["kitchen.local"],
            groups: ["group.bad group"], commands: ["Start Timer", "New Recipe ⌘N", "New Recipe ⌘R", "Open Pantry ⌘N"],
            extensions: ["action Clip", "action Clip accepts text", "gadget X"], app: "Recipes!"))
        XCTAssertEqual(bad.reasons.count, 11, bad.reasons.joined(separator: "\n"))
        XCTAssertTrue(PlatformRequest(PlatformAgent.Input()).asksNothing)
        XCTAssertFalse(PlatformRequest(PlatformAgent.Input(ats: .default)).asksNothing)
    }
}
