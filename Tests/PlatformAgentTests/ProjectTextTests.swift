import Foundation
import XCTest
@testable import PlatformAgent

/// The project file read by its grammar and edited the way Xcode writes it.
final class ProjectTextTests: XCTestCase {
    /// A target referenced before it is defined, and keyed in TargetAttributes: only its definition is the object.
    static let sample = """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tobjectVersion = 77;
        \tobjects = {

        /* Begin PBXFileReference section */
        \t\t130000000000000000000001 /* Recipes.app */ = {isa = PBXFileReference; path = Recipes.app; sourceTree = BUILT_PRODUCTS_DIR; };
        /* End PBXFileReference section */

        /* Begin PBXNativeTarget section */
        \t\t170000000000000000000001 /* Recipes-iOS */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildPhases = (
        \t\t\t);
        \t\t\tname = "Recipes-iOS";
        \t\t\tproductReference = 130000000000000000000001 /* Recipes.app */;
        \t\t};
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
        \t\t1B0000000000000000000001 /* Project object */ = {
        \t\t\tisa = PBXProject;
        \t\t\tattributes = {
        \t\t\t\tTargetAttributes = {
        \t\t\t\t\t170000000000000000000001 = {
        \t\t\t\t\t\tCreatedOnToolsVersion = 26.0;
        \t\t\t\t\t};
        \t\t\t\t};
        \t\t\t};
        \t\t\ttargets = (
        \t\t\t\t170000000000000000000001 /* Recipes-iOS */,
        \t\t\t);
        \t\t};
        /* End PBXProject section */

        /* Begin XCBuildConfiguration section */
        \t\t1D0000000000000000000003 /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGN_STYLE = Automatic;
        \t\t\t\tSWIFT_VERSION = 5.0;
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        /* End XCBuildConfiguration section */
        \t};
        \trootObject = 1B0000000000000000000001 /* Project object */;
        }

        """

    func testAnObjectIsItsDefinitionNotAReferenceToIt() throws {
        let text = ProjectText(Self.sample)
        let target = try XCTUnwrap(text.object("170000000000000000000001"))
        XCTAssertEqual(text.entry("isa", in: target.value).map { text.token($0.value, $0.valueEnd) }, "PBXNativeTarget")
        XCTAssertEqual(text.entry("name", in: target.value).map { text.token($0.value, $0.valueEnd) }, "Recipes-iOS", "a quoted string unquoted")
        let built = try XCTUnwrap(text.object("130000000000000000000001"))
        XCTAssertEqual(text.entries(built.value).map(\.key), ["isa", "path", "sourceTree"], "an object on one line reads the same")
        XCTAssertEqual(text.entry(["attributes", "TargetAttributes"], of: "1B0000000000000000000001").map { text.entries($0.value).map(\.key) },
                       ["170000000000000000000001"])
        XCTAssertNil(text.object("FFFFFFFFFFFFFFFFFFFFFFFF"))
    }

    func testASettingIsSetInOrderOnceAndReplacedWhenItChanges() throws {
        var text = ProjectText(Self.sample)
        func settings() throws -> Int { try XCTUnwrap(text.entry(["buildSettings"], of: "1D0000000000000000000003")).value }
        XCTAssertTrue(text.set("INFOPLIST_FILE", to: "iOS/Info.plist", inDictionaryAt: try settings()))
        XCTAssertTrue(text.text.contains("\t\t\t\tCODE_SIGN_STYLE = Automatic;\n\t\t\t\tINFOPLIST_FILE = iOS/Info.plist;\n\t\t\t\tSWIFT_VERSION = 5.0;\n"),
                      "between its neighbours, indented as they are")
        let once = text.text
        XCTAssertFalse(text.set("INFOPLIST_FILE", to: "iOS/Info.plist", inDictionaryAt: try settings()))
        XCTAssertFalse(text.set("CODE_SIGN_STYLE", to: "\"Automatic\"", inDictionaryAt: try settings()), "the same value quoted is the same value")
        XCTAssertEqual(text.text, once)
        XCTAssertTrue(text.set("SWIFT_VERSION", to: "6.0", inDictionaryAt: try settings()))
        XCTAssertTrue(text.text.contains("SWIFT_VERSION = 6.0;"))
        XCTAssertFalse(text.text.contains("SWIFT_VERSION = 5.0;"))
        XCTAssertTrue(text.set("ALWAYS_FIRST", to: "YES", inDictionaryAt: try settings()))
        XCTAssertTrue(text.text.contains("buildSettings = {\n\t\t\t\tALWAYS_FIRST = YES;\n"))
        XCTAssertNoThrow(try ProjectModel(text: text.text))
    }

    func testAnItemIsAppendedOnItsOwnLineOnce() throws {
        var text = ProjectText(Self.sample)
        let target = try XCTUnwrap(text.object("170000000000000000000001"))
        let phases = text.array("buildPhases", inDictionaryAt: target.value)
        XCTAssertTrue(text.append("AA0000000000000000000001", comment: "Embed Foundation Extensions", toArrayAt: phases))
        XCTAssertTrue(text.text.contains("buildPhases = (\n\t\t\t\tAA0000000000000000000001 /* Embed Foundation Extensions */,\n\t\t\t);"), text.text)
        let again = text.array("buildPhases", inDictionaryAt: try XCTUnwrap(text.object("170000000000000000000001")).value)
        XCTAssertFalse(text.append("AA0000000000000000000001", comment: "Embed Foundation Extensions", toArrayAt: again))
        let dependencies = text.array("dependencies", inDictionaryAt: try XCTUnwrap(text.object("170000000000000000000001")).value)
        XCTAssertTrue(text.append("AA0000000000000000000002", comment: "PBXTargetDependency", toArrayAt: dependencies))
        XCTAssertTrue(text.text.contains("\t\t\tbuildPhases = (\n\t\t\t\tAA0000000000000000000001 /* Embed Foundation Extensions */,\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\tAA0000000000000000000002 /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname"),
                      "a new list goes in key order: \(text.text)")
    }

    func testAnObjectGoesInItsSectionInIDOrderAndANewSectionInIsaOrder() throws {
        var text = ProjectText(Self.sample)
        text.insertObject(ProjectEditor.object("120000000000000000000009", "Debug", ["isa = XCBuildConfiguration;", "name = Debug;"]),
                          id: "120000000000000000000009", isa: "XCBuildConfiguration")
        let configurations = text.text.components(separatedBy: "/* Begin XCBuildConfiguration section */\n")[1]
        XCTAssertTrue(configurations.hasPrefix("\t\t120000000000000000000009 /* Debug */ = {"), "before 1D…, by id")
        text.insertObject(ProjectEditor.object("AB0000000000000000000001", "PBXTargetDependency", ["isa = PBXTargetDependency;"]),
                          id: "AB0000000000000000000001", isa: "PBXTargetDependency")
        let between = try XCTUnwrap(text.text.range(of: "/* End PBXProject section */\n\n/* Begin PBXTargetDependency section */\n\t\tAB0000000000000000000001"))
        XCTAssertTrue(text.text[between.upperBound...].contains("/* End PBXTargetDependency section */\n\n/* Begin XCBuildConfiguration section */"))
        text.insertObject("\t\tAC0000000000000000000001 /* x */ = {isa = PBXBuildFile; };\n", id: "AC0000000000000000000001", isa: "PBXBuildFile")
        XCTAssertTrue(text.text.contains("\tobjects = {\n\n/* Begin PBXBuildFile section */\n\t\tAC0000000000000000000001"), "first by isa: before PBXFileReference")
        let model = try ProjectModel(text: text.text)
        XCTAssertEqual(model.isa("AB0000000000000000000001"), "PBXTargetDependency")
        XCTAssertEqual(model.isa("120000000000000000000009"), "XCBuildConfiguration")
    }

    func testASingleLineBracketStaysOnItsLine() throws {
        var text = ProjectText(Self.sample)
        let built = try XCTUnwrap(text.object("130000000000000000000001"))
        XCTAssertTrue(text.set("includeInIndex", to: "0", inDictionaryAt: built.value))
        XCTAssertTrue(text.text.contains("{isa = PBXFileReference; path = Recipes.app; sourceTree = BUILT_PRODUCTS_DIR; includeInIndex = 0; };"), text.text)
        XCTAssertNoThrow(try ProjectModel(text: text.text))
    }

    func testStringsAreQuotedAsXcodeQuotesThem() {
        XCTAssertEqual(ProjectText.quoted("Recipes"), "Recipes")
        XCTAssertEqual(ProjectText.quoted("iOS/Recipes.entitlements"), "iOS/Recipes.entitlements")
        XCTAssertEqual(ProjectText.quoted("17.0"), "17.0")
        XCTAssertEqual(ProjectText.quoted("Save to Recipes"), "\"Save to Recipes\"")
        XCTAssertEqual(ProjectText.quoted("$(TARGET_NAME)"), "\"$(TARGET_NAME)\"")
        XCTAssertEqual(ProjectText.quoted("public.app-category.lifestyle"), "\"public.app-category.lifestyle\"")
        XCTAssertEqual(ProjectText.quoted(""), "\"\"")
        XCTAssertEqual(ProjectText.quoted(#"a "b" \c"#), #""a \"b\" \\c""#)
    }

    func testObjectIDsAreFreshAndTheSameForTheSameEdit() {
        var ids = ObjectIDs(text: Self.sample)
        let target = ids.make("target SaveRecipeAction")
        XCTAssertEqual(target.count, 24)
        XCTAssertTrue(target.allSatisfy { $0.isHexDigit && !$0.isLowercase })
        XCTAssertFalse(Self.sample.contains(target))
        XCTAssertNotEqual(ids.make("target SaveRecipeAction"), target, "an id is never made twice")
        var again = ObjectIDs(text: Self.sample)
        XCTAssertEqual(again.make("target SaveRecipeAction"), target, "the same edit of the same project makes the same id")
        var crowded = ObjectIDs(text: Self.sample + target)
        XCTAssertNotEqual(crowded.make("target SaveRecipeAction"), target, "and never one the project holds")
    }
}
