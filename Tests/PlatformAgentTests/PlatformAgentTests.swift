import Foundation
import GraniteAgents
import XCTest
@testable import PlatformAgent

/// The package as an app finds it: by its record, with the schema a model is shown and the guide a host prompts with.
final class PlatformAgentTests: XCTestCase {
    func testTheRecordIsFoundWithNothingListed() throws {
        let platform = try XCTUnwrap(GraniteRoster.discovered().package("platform"), "the record is in this test binary")
        XCTAssertEqual(platform.module, "PlatformAgent")
        XCTAssertEqual(platform.summary, PlatformAgent.summary)
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let platform = AnyAgentPackage(PlatformAgent.self)
        XCTAssertEqual(platform.schema, .object([
            .init(name: "keys", schema: .array(.string), required: false),
            .init(name: "schemes", schema: .array(.string), required: false),
            .init(name: "ats", schema: .choice(["default", "arbitrary", "domains"]), required: false),
            .init(name: "atsDomains", schema: .array(.string), required: false),
            .init(name: "groups", schema: .array(.string), required: false),
            .init(name: "keychain", schema: .array(.string), required: false),
            .init(name: "sandbox", schema: .array(.choice(["network", "server", "files", "camera", "photos", "usb"])), required: false),
            .init(name: "commands", schema: .array(.string), required: false),
            .init(name: "extensions", schema: .array(.string), required: false),
            .init(name: "delegate", schema: .array(.choice(["urls", "appearance", "monitors"])), required: false),
            .init(name: "app", schema: .string, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(platform.takesDirectory)
        XCTAssertEqual(Set(platform.fields.keys), ["keys", "schemes", "ats", "atsDomains", "groups", "keychain", "sandbox", "commands",
                                                   "extensions", "delegate", "app"], "a note beside every field the model sees")
        XCTAssertEqual(platform.word, "platform")
        XCTAssertNotNil(platform.word.range(of: #"^[a-z][a-z0-9]{1,31}$"#, options: .regularExpression))
    }

    func testTheGuideTeachesEveryModeWithAnExample() {
        let guide = AnyAgentPackage(PlatformAgent.self).guide
        for word in [#"{"keys": ["#, #"{"schemes": ["#, #""ats": "domains""#, #"{"groups": ["#, #""sandbox": ["#, #"{"commands": ["#,
                     #"{"extensions": ["#, #"{"delegate": ["#, "⇧⌘T", "accepts url,image", ".onAppCommand", ".onSharedInbox",
                     ".onOpenAppURL", ".onWindowClick", "same call twice changes nothing", "refused"] {
            XCTAssertTrue(guide.contains(word), "the guide says \(word)")
        }
        XCTAssertFalse(guide.contains("Loom"), "examples come from another app")
    }

    /// The call as a host makes it: JSON in, the host's folder filled, JSON out naming the files.
    func testACallThroughTheRosterWritesTheFilesItNames() async throws {
        let folder = try Fixture.project()
        let json: [String: Any] = ["keys": [#"camera: "takes photos of the dishes you cook""#], "schemes": ["recipes"],
                                   "commands": ["New Recipe ⌘N"], "directory": folder.path]
        let input = try JSONSerialization.data(withJSONObject: json)
        let answer = try await AnyAgentPackage(PlatformAgent.self).perform(input, host: AgentHost(directory: folder.path, ask: "a camera and a scheme"))
        let result = try JSONDecoder().decode(PlatformResult.self, from: answer)
        XCTAssertEqual(result.path, result.paths.first)
        for path in result.paths {
            XCTAssertTrue(path.hasPrefix(folder.path), path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
        }
        let names = Set(result.paths.map { String($0.dropFirst(folder.path.count + 1)) })
        XCTAssertEqual(names, ["Recipes.xcodeproj/project.pbxproj", "iOS/Info.plist", "macOS/Info.plist", "Shared/AppDelegate.swift",
                               "Shared/Utility/AppURL.swift", "Shared/Extensions/View+OnOpenAppURL.swift", "Shared/Utility/AppCommand.swift",
                               "Shared/Extensions/View+OnAppCommand.swift", "macOS/AppCommands.swift"])
        XCTAssertTrue(result.changes.contains("Info NSCameraUsageDescription"), "\(result.changes)")
        XCTAssertTrue(result.changes.contains("URL scheme recipes"), "\(result.changes)")
        XCTAssertTrue(result.changes.contains("menu File > New Recipe ⌘N"), "\(result.changes)")
        XCTAssertLessThan(answer.count, 2_000, "the answer stays small: the model reads it")
    }

    /// A host on the wire may give its folder only in `AgentHost`: the call still edits the project there, not the
    /// folder the runner was started in.
    func testACallWithNoDirectoryEditsTheHostsFolder() async throws {
        let folder = try Fixture.project()
        let input = try JSONSerialization.data(withJSONObject: ["schemes": ["recipes"], "groups": ["group.com.example.recipes"]])
        let answer = try await AnyAgentPackage(PlatformAgent.self).perform(input, host: AgentHost(directory: folder.path))
        let result = try JSONDecoder().decode(PlatformResult.self, from: answer)
        XCTAssertFalse(result.paths.isEmpty)
        for path in result.paths {
            XCTAssertTrue(path.hasPrefix(folder.path + "/"), "\(path) is under the host's folder")
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
        }
        XCTAssertTrue(result.paths.contains(folder.appendingPathComponent("Recipes.xcodeproj/project.pbxproj").path))
        XCTAssertEqual(PlatformBuildTests.schemes(try Fixture.plist(folder, "iOS/Info.plist")), ["recipes"])
    }
}
