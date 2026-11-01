import Foundation
import XCTest
@testable import PlatformAgent

/// What a call does to a project granite made: where each edit lands, what a later call adds to, and what is
/// refused with nothing written.
final class PlatformCallTests: XCTestCase {
    private func settings(_ folder: URL, _ target: String) throws -> [String: Any] {
        let model = try ProjectModel(text: try Fixture.pbxproj(folder))
        let id = try XCTUnwrap(model.targets.first { model.string("name", of: $0) == target }, target)
        return try XCTUnwrap(model.configurations(of: id).first).settings
    }

    func testInfoKeysAreSettingsWhereTheyApply() throws {
        let folder = try Fixture.project()
        let result = try Fixture.call(.init(keys: Fixture.keys, directory: folder.path))
        let iOS = try settings(folder, "Recipes-iOS"), macOS = try settings(folder, "Recipes-macOS")
        XCTAssertEqual(iOS["INFOPLIST_KEY_NSCameraUsageDescription"] as? String, "Takes photos of the dishes you cook.")
        XCTAssertEqual(macOS["INFOPLIST_KEY_NSCameraUsageDescription"] as? String, "Takes photos of the dishes you cook.")
        XCTAssertEqual(iOS["INFOPLIST_KEY_NSFaceIDUsageDescription"] as? String, "Unlocks your private recipes.")
        XCTAssertNil(macOS["INFOPLIST_KEY_NSFaceIDUsageDescription"], "Face ID is iOS's")
        XCTAssertEqual(macOS["INFOPLIST_KEY_LSApplicationCategoryType"] as? String, "public.app-category.lifestyle", "the category replaced")
        XCTAssertEqual(try Fixture.plist(folder, "iOS/Info.plist")["LSApplicationQueriesSchemes"] as? [String], ["maps", "comgooglemaps"])
        XCTAssertNil(try Fixture.plist(folder, "macOS/Info.plist")["LSApplicationQueriesSchemes"], "queries are iOS's")
        XCTAssertEqual(try Fixture.plist(folder, "macOS/Info.plist")["NSBonjourServices"] as? [String], ["_recipes._tcp"])
        XCTAssertTrue(result.changes.contains("Info NSFaceIDUsageDescription"))
        XCTAssertFalse(result.paths.contains { $0.hasSuffix(".swift") }, "keys alone touch no Swift")
    }

    func testSchemesAndATSMergeIntoEachInfoPlistWhichStaysOutOfTheApp() throws {
        let folder = try Fixture.project()
        try Fixture.call(.init(schemes: ["recipes"], ats: .arbitrary, directory: folder.path))
        for platform in ["iOS", "macOS"] {
            let info = try Fixture.plist(folder, "\(platform)/Info.plist")
            XCTAssertEqual(PlatformBuildTests.schemes(info), ["recipes"])
            XCTAssertEqual((info["NSAppTransportSecurity"] as? [String: Any])?["NSAllowsArbitraryLoads"] as? Bool, true)
            XCTAssertEqual(try settings(folder, "Recipes-\(platform)")["INFOPLIST_FILE"] as? String, "\(platform)/Info.plist")
        }
        let project = try Fixture.pbxproj(folder)
        XCTAssertTrue(project.contains("/* Exceptions for \"iOS\" folder in \"Recipes-iOS\" target */ = {\n\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n\t\t\tmembershipExceptions = (\n\t\t\t\tInfo.plist,\n\t\t\t);"),
                      "the Info.plist is read as a setting says, not copied into the app")
        let result = try Fixture.call(.init(schemes: ["kitchen"], ats: .domains, atsDomains: ["kitchen.local"], directory: folder.path))
        let info = try Fixture.plist(folder, "iOS/Info.plist")
        XCTAssertEqual(PlatformBuildTests.schemes(info), ["recipes", "kitchen"], "a scheme is added, not swapped")
        let security = try XCTUnwrap(info["NSAppTransportSecurity"] as? [String: Any])
        XCTAssertNil(security["NSAllowsArbitraryLoads"], "domains take arbitrary's place")
        XCTAssertNotNil((security["NSExceptionDomains"] as? [String: Any])?["kitchen.local"])
        XCTAssertEqual(result.changes, ["URL scheme kitchen", "ATS allows HTTP to kitchen.local"])
        try Fixture.call(.init(ats: .default, directory: folder.path))
        XCTAssertNil(try Fixture.plist(folder, "macOS/Info.plist")["NSAppTransportSecurity"])
        XCTAssertEqual(try Fixture.pbxproj(folder).components(separatedBy: "isa = PBXFileSystemSynchronizedBuildFileExceptionSet;").count - 1, 2,
                       "one exception set a folder, made once")
    }

    func testEntitlementsAndTheSandboxSettingsSayTheSame() throws {
        let folder = try Fixture.project()
        try Fixture.call(.init(groups: ["group.com.example.recipes"], keychain: ["com.example.recipes.shared"], sandbox: [.network, .files, .camera],
                               directory: folder.path))
        let mac = try Fixture.plist(folder, "macOS/Recipes.entitlements")
        XCTAssertEqual(mac["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(mac["com.apple.security.files.user-selected.read-write"] as? Bool, true)
        XCTAssertEqual(mac["com.apple.security.device.camera"] as? Bool, true)
        XCTAssertEqual(mac["keychain-access-groups"] as? [String], ["$(AppIdentifierPrefix)com.example.recipes.shared"])
        let ios = try Fixture.plist(folder, "iOS/Recipes.entitlements")
        XCTAssertEqual(ios["com.apple.security.application-groups"] as? [String], ["group.com.example.recipes"])
        XCTAssertNil(ios["com.apple.security.app-sandbox"], "the sandbox is macOS's")
        let macSettings = try settings(folder, "Recipes-macOS")
        XCTAssertEqual(macSettings["CODE_SIGN_ENTITLEMENTS"] as? String, "macOS/Recipes.entitlements")
        XCTAssertEqual(macSettings["ENABLE_USER_SELECTED_FILES"] as? String, "readwrite", "not the template's readonly beside the file's read-write")
        XCTAssertEqual(macSettings["ENABLE_RESOURCE_ACCESS_CAMERA"] as? String, "YES")
        XCTAssertEqual(try settings(folder, "Recipes-iOS")["CODE_SIGN_ENTITLEMENTS"] as? String, "iOS/Recipes.entitlements")
    }

    func testTheDelegateDoesWhatItIsAskedAndKeepsWhatItDid() throws {
        let folder = try Fixture.project()
        try Fixture.call(.init(delegate: [.appearance], directory: folder.path))
        var delegate = try Fixture.text(folder, AppDelegateFile.path)
        XCTAssertTrue(delegate.contains("UITextView.appearance().backgroundColor = .clear"))
        XCTAssertFalse(delegate.contains("AppURL"), "URLs only when asked")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(AppURLFiles.typePath).path))

        let result = try Fixture.call(.init(schemes: ["recipes"], delegate: [.monitors], directory: folder.path))
        delegate = try Fixture.text(folder, AppDelegateFile.path)
        XCTAssertEqual(AppDelegateFile.features(in: delegate), [.appearance, .urls, .monitors], "a scheme turns on urls; appearance is kept")
        XCTAssertTrue(delegate.contains("configuration.delegateClass = SceneDelegate.self"), "URLs arrive at the scene on iOS")
        XCTAssertTrue(delegate.contains("func application(_ application: NSApplication, open urls: [URL])"))
        XCTAssertTrue(delegate.contains("NSEvent.addGlobalMonitorForEvents"))
        XCTAssertTrue(try Fixture.text(folder, WindowClickFiles.typePath).contains("nyc.stoic.Granite.App.Interaction.windowClickedOutside"))
        XCTAssertTrue(try Fixture.text(folder, AppURLFiles.modifierPath).contains("func onOpenAppURL(perform action: @escaping (URL) -> Void) -> some View"))
        XCTAssertEqual(result.changes.filter { $0.hasPrefix("delegate") }, ["delegate urls, monitors"])
        XCTAssertTrue(result.notes.contains { $0.contains(".onOpenAppURL") })
    }

    func testMenuCommandsAreAddedToNotReplaced() throws {
        let folder = try Fixture.project()
        let first = try Fixture.call(.init(commands: ["New Recipe ⌘N", "Refresh ⌘R"], directory: folder.path))
        XCTAssertTrue(first.notes.contains("New Recipe takes ⌘N, so it replaces File › New Window."))
        try Fixture.call(.init(commands: ["Kitchen > Start Timer ⇧⌘T", "Refresh ⌥⌘R"], directory: folder.path))
        let type = try Fixture.text(folder, CommandFiles.typePath)
        XCTAssertEqual(CommandFiles.commands(in: type).map(\.line), ["File > New Recipe ⌘N", "View > Refresh ⌥⌘R", "Kitchen > Start Timer ⇧⌘T"],
                       "an earlier call's commands are kept; one said again takes its new shortcut")
        let menu = try Fixture.text(folder, CommandFiles.menuPath)
        XCTAssertTrue(menu.contains("CommandGroup(replacing: .newItem) {\n            Button(\"New Recipe\") {\n                AppCommand.newRecipe.post()\n            }\n            .keyboardShortcut(\"n\")"), menu)
        XCTAssertTrue(menu.contains("CommandGroup(after: .toolbar)"))
        XCTAssertTrue(menu.contains("CommandMenu(\"Kitchen\")"))
        XCTAssertTrue(menu.contains(".keyboardShortcut(\"r\", modifiers: [.command, .option])"))
        XCTAssertTrue(try Fixture.text(folder, CommandFiles.modifierPath).contains("func onAppCommand(_ command: AppCommand"))
        XCTAssertThrowsError(try Fixture.call(.init(commands: ["Open Pantry ⌘N"], directory: folder.path))) { error in
            XCTAssertTrue("\(error)".contains("⌘N is New Recipe's already"), "\(error)")
        }
    }

    func testAnExtensionIsATargetEmbeddedInTheiOSApp() throws {
        let folder = try Fixture.project()
        let result = try Fixture.call(.init(extensions: [Fixture.extensions[0]], directory: folder.path))
        XCTAssertTrue(result.notes.contains("No app group was given: the extensions share group.com.example.recipes with the app."))
        XCTAssertTrue(result.notes.contains("No URL scheme was given: the extensions open the app with recipes://."))
        XCTAssertEqual(result.changes.filter { $0.hasPrefix("extension") }, ["extension SaveRecipeAction (action: url, image)"])
        let model = try ProjectModel(text: try Fixture.pbxproj(folder))
        let target = try XCTUnwrap(model.targets.first { model.string("name", of: $0) == "SaveRecipeAction" })
        XCTAssertEqual(model.string("productType", of: target), "com.apple.product-type.app-extension")
        let ext = try XCTUnwrap(model.configurations(of: target).first).settings
        XCTAssertEqual(ext["PRODUCT_BUNDLE_IDENTIFIER"] as? String, "com.example.recipes.SaveRecipeAction")
        XCTAssertEqual(ext["INFOPLIST_FILE"] as? String, "Action/SaveRecipe/Info.plist")
        XCTAssertEqual(ext["INFOPLIST_KEY_CFBundleDisplayName"] as? String, "Save to Recipes")
        XCTAssertEqual(ext["SWIFT_VERSION"] as? String, "5.0", "built as the app is")
        let host = try XCTUnwrap(model.targets.first { model.string("name", of: $0) == "Recipes-iOS" })
        let embed = try XCTUnwrap(model.list("buildPhases", of: host).first { model.isa($0) == "PBXCopyFilesBuildPhase" })
        XCTAssertEqual(model.string("name", of: embed), "Embed Foundation Extensions")
        XCTAssertEqual(model.list("dependencies", of: host).count, 1)
        XCTAssertNil(model.targets.first { model.string("name", of: $0) == "Recipes-macOS" }.flatMap { model.list("dependencies", of: $0).first })

        let controller = try Fixture.text(folder, "Action/SaveRecipe/SaveRecipeViewController.swift")
        XCTAssertTrue(controller.contains("final class SaveRecipeViewController: UIViewController {"))
        XCTAssertTrue(controller.contains("private let appURL = URL(string: \"recipes://inbox\")!"))
        XCTAssertTrue(controller.contains("UTType.image.identifier"))
        XCTAssertFalse(controller.contains("UTType.plainText"), "only what it accepts")
        XCTAssertTrue(controller.contains("application.open(appURL, options: [:], completionHandler: nil)"))
        let inbox = try Fixture.text(folder, InboxFiles.typePath)
        XCTAssertTrue(inbox.contains("static let group = \"group.com.example.recipes\""))
        XCTAssertEqual(try Fixture.plist(folder, "Action/SaveRecipe/SaveRecipe.entitlements")["com.apple.security.application-groups"] as? [String],
                       ["group.com.example.recipes"])
        XCTAssertEqual(try Fixture.plist(folder, "iOS/Recipes.entitlements")["com.apple.security.application-groups"] as? [String],
                       ["group.com.example.recipes"], "the app has the group too")
        XCTAssertEqual(PlatformBuildTests.schemes(try Fixture.plist(folder, "iOS/Info.plist")), ["recipes"], "and the scheme it is opened by")

        let second = try Fixture.call(.init(extensions: [Fixture.extensions[1]], directory: folder.path))
        XCTAssertEqual(second.changes, ["extension ShareToKitchenShare (share: image, text)"])
        let after = try ProjectModel(text: try Fixture.pbxproj(folder))
        XCTAssertEqual(after.list("buildPhases", of: host).filter { after.isa($0) == "PBXCopyFilesBuildPhase" }.count, 1, "one embed phase holds both")
        let phase = try XCTUnwrap(after.list("buildPhases", of: host).first { after.isa($0) == "PBXCopyFilesBuildPhase" })
        XCTAssertEqual(after.list("files", of: phase).count, 2)
        XCTAssertEqual(after.list("children", of: try XCTUnwrap(after.mainGroup)).compactMap { after.string("path", of: $0) },
                       ["Shared", "Components", "Services", "iOS", "macOS", "Action", "Share"], "kind groups before Products")
    }

    func testTheSameCallTwiceWritesNothingAndANewKeyAddsOnlyItself() throws {
        let folder = try Fixture.project()
        let first = try Fixture.call(Fixture.everything(folder))
        XCTAssertEqual(first.paths.count, 21)
        let project = try Fixture.pbxproj(folder)
        let again = try Fixture.call(Fixture.everything(folder))
        XCTAssertEqual(again, PlatformResult(path: nil, paths: [], changes: [], notes: ["The project already has everything this call asks for."]))
        XCTAssertEqual(try Fixture.pbxproj(folder), project)
        let more = try Fixture.call(.init(keys: [#"microphone: "listens for "next step"""#], directory: folder.path))
        XCTAssertEqual(more.changes, ["Info NSMicrophoneUsageDescription"])
        XCTAssertEqual(more.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["project.pbxproj"])
        XCTAssertEqual(try Fixture.pbxproj(folder).components(separatedBy: "\n").count - project.components(separatedBy: "\n").count, 4,
                       "a line in each of the four app configurations")
    }

    func testWhatCannotBeDoneIsRefusedWholeAndNothingIsWritten() throws {
        let folder = try Fixture.project()
        // The project without its macOS app: an iOS-only app.
        let path = folder.appendingPathComponent("Recipes.xcodeproj/project.pbxproj")
        let text = try String(contentsOf: path, encoding: .utf8)
        try text.replacingOccurrences(of: "\t\t\t\t170000000000000000000002 /* Recipes-macOS */,\n\t\t\t);\n\t\t};\n/* End PBXProject", with: "\t\t\t);\n\t\t};\n/* End PBXProject")
            .write(to: path, atomically: true, encoding: .utf8)
        let before = try Fixture.pbxproj(folder)
        XCTAssertThrowsError(try Fixture.call(.init(keys: ["camera: x"], sandbox: [.network], commands: ["New Recipe ⌘N"], delegate: [.monitors],
                                                    directory: folder.path))) { error in
            guard case PlatformError.refused(let reasons) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(reasons.count, 3, reasons.joined(separator: "\n"))
            XCTAssertTrue(reasons.contains("menu commands are macOS's, and the project has no macOS app target"))
        }
        XCTAssertEqual(try Fixture.pbxproj(folder), before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("iOS/Info.plist").path))
        XCTAssertThrowsError(try Fixture.call(.init(directory: folder.path))) { XCTAssertEqual($0 as? PlatformError, .nothing) }
        XCTAssertThrowsError(try Fixture.call(.init(commands: ["Start Timer"], extensions: ["widget X"], directory: folder.path))) { error in
            XCTAssertTrue("\(error)".hasPrefix("2 things cannot be done, so nothing was written:"), "\(error)")
        }
    }

    func testAnOlderProjectTakesWhatItCanAndSaysWhatToAdd() throws {
        let folder = try Fixture.project()
        // Granite's project as Xcode 15 kept it: objectVersion 60, its folders not synchronized.
        let path = folder.appendingPathComponent("Recipes.xcodeproj/project.pbxproj")
        var text = try String(contentsOf: path, encoding: .utf8).replacingOccurrences(of: "objectVersion = 77;", with: "objectVersion = 60;")
        while let start = text.range(of: "\t\t\tfileSystemSynchronizedGroups = ("), let end = text.range(of: ");\n", range: start.upperBound..<text.endIndex) {
            text.removeSubrange(start.lowerBound..<end.upperBound)
        }
        try text.write(to: path, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Fixture.call(.init(extensions: ["action Clip"], directory: folder.path))) { error in
            XCTAssertTrue("\(error)".contains("the project is objectVersion 60: an extension is added as a synchronized folder"), "\(error)")
        }
        let result = try Fixture.call(.init(keys: ["camera: takes photos"], commands: ["New Recipe ⌘N"], directory: folder.path))
        XCTAssertTrue(result.changes.contains("Info NSCameraUsageDescription"))
        XCTAssertTrue(result.notes.contains("macOS/AppCommands.swift is not in a folder Recipes-macOS builds: add it to the target in Xcode."), "\(result.notes)")
        XCTAssertTrue(result.notes.contains { $0.hasPrefix("Shared/Utility/AppCommand.swift and Shared/Extensions/View+OnAppCommand.swift are not in a folder Recipes-iOS and Recipes-macOS build") },
                      "\(result.notes)")
    }

    func testTheProjectIsTheOneInTheFolderOrTheOneNamed() throws {
        let empty = try Fixture.folder()
        XCTAssertThrowsError(try Fixture.call(.init(schemes: ["recipes"], directory: empty.path))) { error in
            XCTAssertTrue("\(error)".contains("there is no Xcode project in"), "\(error)")
        }
        let folder = try Fixture.project()
        try FixtureProject.make(in: folder, name: "Pantry", bundleID: "com.example.pantry")
        XCTAssertThrowsError(try Fixture.call(.init(schemes: ["recipes"], directory: folder.path))) { error in
            XCTAssertTrue("\(error)".contains("holds 2 projects (Pantry.xcodeproj, Recipes.xcodeproj): name the app with `app`"), "\(error)")
        }
        try Fixture.call(.init(groups: ["group.com.example.pantry"], app: "Pantry", directory: folder.path))
        XCTAssertNotNil(try Fixture.plist(folder, "iOS/Pantry.entitlements")["com.apple.security.application-groups"])
        XCTAssertFalse(try Fixture.pbxproj(folder, name: "Recipes").contains("CODE_SIGN_ENTITLEMENTS"))
    }
}
