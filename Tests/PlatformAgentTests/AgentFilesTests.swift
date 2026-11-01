import Foundation
import XCTest
@testable import PlatformAgent

/// The host's folder, kept as the host wrote it.
final class AgentFilesTests: XCTestCase {
    func testPathsKeepTheHostsFormAndResolveParents() {
        let files = AgentFiles(directory: "/private/tmp/app")
        XCTAssertEqual(files.resolve("Shared/Utility").path, "/private/tmp/app/Shared/Utility", "/private is not dropped")
        XCTAssertEqual(files.resolve("Shared/../macOS/./AppCommands.swift").path, "/private/tmp/app/macOS/AppCommands.swift")
        XCTAssertEqual(files.resolve("/abs/a/../b").path, "/abs/b")
        XCTAssertEqual(files.relative(files.resolve("Shared/AppDelegate.swift")), "Shared/AppDelegate.swift")
        XCTAssertEqual(files.relative(URL(fileURLWithPath: "/elsewhere/x")), "/elsewhere/x")
    }

    func testSwiftThatDoesNotParseLandsNowhere() throws {
        let folder = try Fixture.folder()
        let files = AgentFiles(directory: folder.path)
        XCTAssertThrowsError(try files.write([(folder.appendingPathComponent("Info.plist"), "<plist/>"),
                                              (folder.appendingPathComponent("Shared/Odd.swift"), "struct Odd {")])) { error in
            XCTAssertTrue("\(error)".contains("does not parse"), "\(error)")
            XCTAssertTrue("\(error)".contains("Shared/Odd.swift"), "the file is named as the project knows it: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Info.plist").path), "whole or nothing")
    }
}
