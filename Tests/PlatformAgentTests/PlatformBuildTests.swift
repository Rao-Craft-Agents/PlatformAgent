import Foundation
import XCTest
@testable import PlatformAgent

/// The output built and checked as an app would be: every input applied to a project shaped as granite makes one,
/// a view that uses every API the agent wrote, both schemes built with xcodebuild (and again in Swift 6 mode), the
/// built Info.plists, entitlements and embedded extensions read, and the notifications run in a small program.
/// Gated (`PLATFORM_BUILD=1`): the builds take a few minutes.
final class PlatformBuildTests: XCTestCase {
    func testEveryInputBuildsOnBothPlatforms() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PLATFORM_BUILD"] == "1", "set PLATFORM_BUILD=1 to build the output")
        let folder = try Fixture.project()
        let derived = try builds()

        let first = try Fixture.call(Fixture.everything(folder))
        XCTAssertFalse(first.paths.isEmpty)
        let project = try Fixture.pbxproj(folder)
        let again = try Fixture.call(Fixture.everything(folder))
        XCTAssertEqual(again.paths, [], "a second identical call writes nothing")
        XCTAssertEqual(try Fixture.pbxproj(folder), project)

        try Self.uses.write(to: folder.appendingPathComponent("Components/Home/Home+Platform.swift"), atomically: true, encoding: .utf8)

        try build(folder, scheme: "Recipes-macOS", destination: "platform=macOS", derived: derived, ["CODE_SIGNING_ALLOWED=NO"])
        try build(folder, scheme: "Recipes-iOS", destination: "generic/platform=iOS Simulator", derived: derived, [])

        // The macOS app: its Info.plist merged, nothing of iOS's, no Info.plist copied as a resource.
        let mac = derived.appendingPathComponent("Build/Products/Debug/Recipes.app/Contents")
        let macInfo = try plist(mac.appendingPathComponent("Info.plist"))
        XCTAssertEqual(Self.schemes(macInfo), ["recipes"])
        XCTAssertEqual(macInfo["NSCameraUsageDescription"] as? String, "Takes photos of the dishes you cook.")
        XCTAssertEqual(macInfo["NSLocalNetworkUsageDescription"] as? String, "Finds the kitchen display on your network.")
        XCTAssertEqual(macInfo["LSApplicationCategoryType"] as? String, "public.app-category.lifestyle")
        XCTAssertEqual(macInfo["NSBonjourServices"] as? [String], ["_recipes._tcp"])
        XCTAssertNil(macInfo["NSFaceIDUsageDescription"], "Face ID is iOS's")
        let macDomains = (macInfo["NSAppTransportSecurity"] as? [String: Any])?["NSExceptionDomains"] as? [String: Any]
        XCTAssertEqual(Set(macDomains?.keys ?? [:].keys), ["kitchen.local", "pantry.example.com"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: mac.appendingPathComponent("Resources/Info.plist").path))
        XCTAssertEqual(try Self.files(in: mac, ending: ".entitlements"), [], "an entitlements file is signed in, never copied")

        // The iOS app: its Info.plist merged, both extensions embedded and declared, the app group signed in.
        let ios = derived.appendingPathComponent("Build/Products/Debug-iphonesimulator/Recipes.app")
        let iosInfo = try plist(ios.appendingPathComponent("Info.plist"))
        XCTAssertEqual(Self.schemes(iosInfo), ["recipes"])
        XCTAssertEqual(iosInfo["NSFaceIDUsageDescription"] as? String, "Unlocks your private recipes.")
        XCTAssertEqual(iosInfo["NSPhotoLibraryUsageDescription"] as? String, "Picks a photo for a recipe.")
        XCTAssertEqual(iosInfo["LSApplicationQueriesSchemes"] as? [String], ["maps", "comgooglemaps"])
        for (appex, point, rule) in [("SaveRecipeAction", "com.apple.ui-services", "NSExtensionActivationSupportsWebURLWithMaxCount"),
                                     ("ShareToKitchenShare", "com.apple.share-services", "NSExtensionActivationSupportsText")] {
            let bundle = ios.appendingPathComponent("PlugIns/\(appex).appex")
            let info = try plist(bundle.appendingPathComponent("Info.plist"))
            let declared = info["NSExtension"] as? [String: Any]
            XCTAssertEqual(declared?["NSExtensionPointIdentifier"] as? String, point)
            XCTAssertEqual(declared?["NSExtensionPrincipalClass"] as? String, "\(appex).\(appex.hasSuffix("Action") ? "SaveRecipe" : "ShareToKitchen")ViewController")
            let rules = (declared?["NSExtensionAttributes"] as? [String: Any])?["NSExtensionActivationRule"] as? [String: Any]
            XCTAssertNotNil(rules?[rule], "\(appex) accepts what its line says")
            XCTAssertEqual(info["CFBundleIdentifier"] as? String, "com.example.recipes.\(appex)")
            XCTAssertEqual(info["CFBundleShortVersionString"] as? String, iosInfo["CFBundleShortVersionString"] as? String)
            let symbols = try run("/usr/bin/nm", ["-gU", bundle.appendingPathComponent(appex).path, bundle.appendingPathComponent("\(appex).debug.dylib").path])
            XCTAssertTrue(symbols.contains("ViewControllerC"), "the principal class is in the extension's binary")
        }
        XCTAssertEqual(try Self.files(in: ios, ending: ".entitlements"), [])
        XCTAssertEqual(try Self.files(in: ios, ending: "Info.plist").sorted(),
                       ["Info.plist", "PlugIns/SaveRecipeAction.appex/Info.plist", "PlugIns/ShareToKitchenShare.appex/Info.plist"],
                       "each bundle has its own Info.plist, once")
        let intermediates = derived.appendingPathComponent("Build/Intermediates.noindex/Recipes.build/Debug-iphonesimulator")
        let appGroups = try plist(intermediates.appendingPathComponent("Recipes-iOS.build/Recipes.app-Simulated.xcent"))
        XCTAssertEqual(appGroups["com.apple.security.application-groups"] as? [String], ["group.com.example.recipes"])
        let extensionGroups = try plist(intermediates.appendingPathComponent("SaveRecipeAction.build/SaveRecipeAction.appex-Simulated.xcent"))
        XCTAssertEqual(extensionGroups["com.apple.security.application-groups"] as? [String], ["group.com.example.recipes"])

        // Swift 6 language mode: nothing the agent writes is Granite reducer code, so it builds there too.
        let strict = try builds()
        try build(folder, scheme: "Recipes-iOS", destination: "generic/platform=iOS Simulator", derived: strict, ["SWIFT_VERSION=6.0"])
        try build(folder, scheme: "Recipes-macOS", destination: "platform=macOS", derived: strict, ["SWIFT_VERSION=6.0", "CODE_SIGNING_ALLOWED=NO"])

        // The sandbox as signed: a project given only the sandbox (app groups would need a provisioning profile),
        // signed ad hoc, so Xcode merges the file with its own settings; they say the same, read-only nowhere.
        let sandboxed = try Fixture.project()
        try Fixture.call(PlatformAgent.Input(sandbox: PlatformSandbox.allCases, directory: sandboxed.path))
        let signed = try builds()
        try build(sandboxed, scheme: "Recipes-macOS", destination: "platform=macOS", derived: signed,
                  ["CODE_SIGN_IDENTITY=-", "CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM="])
        let sandbox = try plist(signed.appendingPathComponent("Build/Intermediates.noindex/Recipes.build/Debug/Recipes-macOS.build/Recipes.app.xcent"))
        for key in ["com.apple.security.app-sandbox", "com.apple.security.network.client", "com.apple.security.network.server",
                    "com.apple.security.files.user-selected.read-write", "com.apple.security.device.camera",
                    "com.apple.security.personal-information.photos-library", "com.apple.security.device.usb"] {
            XCTAssertEqual(sandbox[key] as? Bool, true, key)
        }
        XCTAssertNil(sandbox["com.apple.security.files.user-selected.read-only"], "the file and the settings say the same")

        // The notifications and the URL queue, run: a program built from the files the agent wrote.
        let program = try Fixture.folder()
        try Self.check.write(to: program.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        let sources = ["Shared/Utility/AppURL.swift", "Shared/Utility/AppCommand.swift", "Shared/Utility/WindowClick.swift"].map { folder.appendingPathComponent($0).path }
        _ = try run("/usr/bin/xcrun", ["swiftc", "-swift-version", "6", "-o", program.appendingPathComponent("check").path,
                                       program.appendingPathComponent("main.swift").path] + sources)
        XCTAssertEqual(try run(program.appendingPathComponent("check").path, []), "ok\n")
    }

    /// A view of the app that uses every API the agent wrote, as the app's own views would.
    static let uses = #"""
        import SwiftUI

        struct PlatformUses: View {
            @State private var opened: [URL] = []
            @State private var shared: [SharedInbox.Item] = []
            @State private var clicksOutside = 0
            @State private var chosen: [AppCommand] = []

            var body: some View {
                List {
                    ForEach(opened, id: \.self) { url in
                        Text(url.absoluteString)
                    }
                    ForEach(shared, id: \.self) { item in
                        switch item.content {
                        case .url(let url): Text(url.absoluteString)
                        case .text(let text): Text(text)
                        case .image(let file): Text(file.lastPathComponent)
                        }
                    }
                }
                .onOpenAppURL { url in opened.append(url) }
                .onSharedInbox { items in shared += items }
                .onSharedInbox(from: "SaveRecipe") { items in shared += items }
                .onWindowClick { click in if click == .outside { clicksOutside += 1 } }
                .onAppCommand(.newRecipe) { chosen.append(.newRecipe) }
                .onAppCommand(.startTimer) { chosen.append(.startTimer) }
            }
        }

        """#

    /// What the program checks: a URL waits for the view that takes it, once; a command and a click are posted
    /// under the names the views and Granite's windows listen for.
    static let check = #"""
        import Foundation

        @MainActor
        func check() {
            let url = URL(string: "recipes://inbox")!
            AppURL.open(url)
            precondition(AppURL.take() == [url], "a URL waits until it is taken")
            precondition(AppURL.take().isEmpty, "and is taken once")

            nonisolated(unsafe) var heard: [String] = []
            let center = NotificationCenter.default
            let tokens = [AppCommand.newRecipe.notification, WindowClick.outside.notification, AppURL.notification].map { name in
                center.addObserver(forName: name, object: nil, queue: nil) { note in heard.append(note.name.rawValue) }
            }
            AppCommand.newRecipe.post()
            WindowClick.outside.post()
            AppURL.open(url)
            tokens.forEach(center.removeObserver)
            precondition(heard == ["AppCommand.newRecipe", "nyc.stoic.Granite.App.Interaction.windowClickedOutside", "AppURL"], "\(heard)")
            precondition(AppCommand.allCases.map(\.rawValue) == ["newRecipe", "refresh", "startTimer", "toggleSidebar"], "\(AppCommand.allCases)")
            print("ok")
        }

        MainActor.assumeIsolated { check() }

        """#

    /// The files in `bundle` whose names end in `suffix`, relative to it.
    static func files(in bundle: URL, ending suffix: String) throws -> [String] {
        let all = FileManager.default.enumerator(atPath: bundle.path)?.compactMap { $0 as? String } ?? []
        return all.filter { $0.hasSuffix(suffix) && !$0.contains("_CodeSignature") }
    }

    /// A folder for xcodebuild's derived data, removed when the test ends: a build leaves some 400 MB.
    private func builds() throws -> URL {
        let folder = try Fixture.folder()
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    static func schemes(_ info: [String: Any]) -> [String] {
        (info["CFBundleURLTypes"] as? [[String: Any]] ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    private func plist(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any], url.path)
    }

    private func build(_ folder: URL, scheme: String, destination: String, derived: URL, _ settings: [String]) throws {
        let log = try run("/usr/bin/xcrun", ["xcodebuild", "-project", folder.appendingPathComponent("Recipes.xcodeproj").path, "-scheme", scheme,
                                             "-destination", destination, "-derivedDataPath", derived.path] + settings + ["build"], allowFailure: true)
        let errors = log.split(separator: "\n").filter { $0.contains("error:") || $0.contains("warning: The Copy Bundle Resources") }
        XCTAssertTrue(log.contains("** BUILD SUCCEEDED **"), "\(scheme) \(settings): \(errors.prefix(20).joined(separator: "\n"))")
        XCTAssertTrue(errors.isEmpty, "\(scheme) \(settings): \(errors.prefix(20).joined(separator: "\n"))")
    }

    @discardableResult
    private func run(_ tool: String, _ arguments: [String], allowFailure: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        if !allowFailure { XCTAssertEqual(process.terminationStatus, 0, "\(tool) \(arguments.prefix(3)): \(text.suffix(2_000))") }
        return text
    }
}
