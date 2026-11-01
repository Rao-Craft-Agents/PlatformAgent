//  WHAT: The edits a call makes to a project file, said as what they are: a build setting on a target, a file
//        kept out of a synchronized folder's target, an app extension target embedded in the iOS app. Each edit
//        looks first and adds only what is missing, so the same call twice edits once.
//  PIN:  ONE EDIT, ONE PLACE. Every object goes where Xcode keeps its kind and every reference beside its comment,
//        so the project reads in Xcode as if Xcode had made the change.

import Foundation

struct ProjectEditor {
    let project: XcodeProject
    private(set) var text: ProjectText
    private var ids: ObjectIDs
    /// Exception sets this call made, by folder and target.
    private var exceptionSets: [String: String] = [:]
    /// Groups for a kind of extension (`Action`) and embed phases this call made, so a second extension joins them.
    private var kindGroups: [String: String] = [:]
    private var embedPhases: [String: String] = [:]

    init(project: XcodeProject) {
        self.project = project
        text = ProjectText(project.text)
        ids = ObjectIDs(text: project.text)
    }

    var model: ProjectModel { project.model }
    var changed: Bool { text.text != project.text }

    // MARK: - Settings

    /// Sets build setting `key` to `value` in every configuration of `target`; false when every one had it.
    @discardableResult
    mutating func set(_ key: String, _ value: String, on target: AppTarget) -> Bool {
        var changed = false
        for configuration in target.configurations {
            guard let object = text.object(configuration.id), text.isDictionary(object.value),
                  let settings = text.entry("buildSettings", in: object.value), text.isDictionary(settings.value) else { continue }
            changed = text.set(key, to: ProjectText.quoted(value), inDictionaryAt: settings.value) || changed
        }
        return changed
    }

    // MARK: - Synchronized folders

    /// Keeps `path` (relative to the project) out of `target`'s synchronized folder that holds it, so Xcode does
    /// not copy it into the app as well as reading it as a setting says (an Info.plist).
    @discardableResult
    mutating func keepOut(_ path: String, of target: AppTarget) -> Bool {
        guard let folder = target.folder(holding: path) else { return false }
        let known = model.list("exceptions", of: folder.id).first {
            model.isa($0) == "PBXFileSystemSynchronizedBuildFileExceptionSet" && model.string("target", of: $0) == target.id
        }
        if let set = known ?? exceptionSets[folder.id + target.id], let object = text.object(set) {
            let list = text.array("membershipExceptions", inDictionaryAt: object.value)
            return text.append(ProjectText.quoted(folder.inside), comment: nil, toArrayAt: list)
        }
        let name = folder.path.split(separator: "/").last.map(String.init) ?? folder.path
        let id = makeExceptionSet(folder: name, inside: folder.inside, target: target.id, targetName: target.name)
        exceptionSets[folder.id + target.id] = id
        if let group = text.object(folder.id) {
            let list = text.array("exceptions", inDictionaryAt: group.value)
            text.append(id, comment: Self.exceptionComment(name, target.name), toArrayAt: list)
        }
        return true
    }

    private static func exceptionComment(_ folder: String, _ target: String) -> String {
        "Exceptions for \"\(folder)\" folder in \"\(target)\" target"
    }

    private mutating func makeExceptionSet(folder: String, inside: String, target: String, targetName: String) -> String {
        let id = ids.make("exceptions \(folder) \(targetName)")
        text.insertObject(Self.object(id, Self.exceptionComment(folder, targetName), [
            "isa = PBXFileSystemSynchronizedBuildFileExceptionSet;",
            "membershipExceptions = (",
            "\t\(ProjectText.quoted(inside)),",
            ");",
            "target = \(target) /* \(targetName) */;",
        ]), id: id, isa: "PBXFileSystemSynchronizedBuildFileExceptionSet")
        return id
    }

    // MARK: - App extensions

    /// Adds `made` as an app extension target built from its folder, embedded in `host`; false when the project
    /// has its target already.
    @discardableResult
    mutating func add(_ made: AppExtension, host: AppTarget, bundleID: String) -> Bool {
        guard project.target(named: made.target) == nil, let mainGroup = model.mainGroup else { return false }
        let target = ids.make("target \(made.target)")
        let product = ids.make("product \(made.target)")
        let folder = ids.make("folder \(made.folder)")
        let sources = ids.make("sources \(made.target)"), frameworks = ids.make("frameworks \(made.target)")
        let resources = ids.make("resources \(made.target)"), list = ids.make("configurations \(made.target)")
        let appex = "\(made.target).appex"

        // The folder, its Info.plist kept out of the target's resources, inside a group for its kind.
        let exceptions = makeExceptionSet(folder: made.name, inside: "Info.plist", target: target, targetName: made.target)
        text.insertObject(Self.object(folder, made.name, [
            "isa = PBXFileSystemSynchronizedRootGroup;",
            "exceptions = (",
            "\t\(exceptions) /* \(Self.exceptionComment(made.name, made.target)) */,",
            ");",
            "path = \(ProjectText.quoted(made.name));",
            "sourceTree = \"<group>\";",
        ]), id: folder, isa: "PBXFileSystemSynchronizedRootGroup")
        let kindGroup = kindGroups[made.kind.folder] ?? model.list("children", of: mainGroup).first {
            model.isa($0) == "PBXGroup" && (model.string("path", of: $0) ?? model.string("name", of: $0)) == made.kind.folder
        }
        if let kindGroup, let object = text.object(kindGroup) {
            text.append(folder, comment: made.name, toArrayAt: text.array("children", inDictionaryAt: object.value))
        } else {
            let group = ids.make("group \(made.kind.folder)")
            text.insertObject(Self.object(group, made.kind.folder, [
                "isa = PBXGroup;",
                "children = (",
                "\t\(folder) /* \(made.name) */,",
                ");",
                "path = \(made.kind.folder);",
                "sourceTree = \"<group>\";",
            ]), id: group, isa: "PBXGroup")
            insert(group, comment: made.kind.folder, intoChildrenOf: mainGroup, before: model.productsGroup)
            kindGroups[made.kind.folder] = group
        }

        // The product, and the target that builds it.
        text.insertObject("\t\t\(product) /* \(appex) */ = {isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = \(ProjectText.quoted(appex)); sourceTree = BUILT_PRODUCTS_DIR; };\n",
                          id: product, isa: "PBXFileReference")
        if let products = model.productsGroup, let object = text.object(products) {
            text.append(product, comment: appex, toArrayAt: text.array("children", inDictionaryAt: object.value))
        }
        for (id, isa, name) in [(sources, "PBXSourcesBuildPhase", "Sources"), (frameworks, "PBXFrameworksBuildPhase", "Frameworks"),
                                (resources, "PBXResourcesBuildPhase", "Resources")] {
            text.insertObject(Self.object(id, name, ["isa = \(isa);", "buildActionMask = 2147483647;", "files = (", ");",
                                                     "runOnlyForDeploymentPostprocessing = 0;"]), id: id, isa: isa)
        }
        let listComment = "Build configuration list for PBXNativeTarget \"\(made.target)\""
        text.insertObject(Self.object(target, made.target, [
            "isa = PBXNativeTarget;",
            "buildConfigurationList = \(list) /* \(listComment) */;",
            "buildPhases = (",
            "\t\(sources) /* Sources */,",
            "\t\(frameworks) /* Frameworks */,",
            "\t\(resources) /* Resources */,",
            ");",
            "buildRules = (",
            ");",
            "dependencies = (",
            ");",
            "fileSystemSynchronizedGroups = (",
            "\t\(folder) /* \(made.name) */,",
            ");",
            "name = \(ProjectText.quoted(made.target));",
            "packageProductDependencies = (",
            ");",
            "productName = \(ProjectText.quoted(made.target));",
            "productReference = \(product) /* \(appex) */;",
            "productType = \"com.apple.product-type.app-extension\";",
        ]), id: target, isa: "PBXNativeTarget")

        // Its configurations, one for each of the host's, from the host's settings.
        var configurations: [(id: String, name: String)] = []
        for configuration in host.configurations {
            let id = ids.make("configuration \(made.target) \(configuration.name)")
            let settings = extensionSettings(made, host: host, configuration: configuration.name, bundleID: bundleID)
            var lines = ["isa = XCBuildConfiguration;", "buildSettings = {"]
            for (key, value) in settings.sorted(by: { ProjectText.precedes($0.key, $1.key) }) {
                if let items = value as? [String] {
                    lines.append("\t\(key) = (")
                    lines += items.map { "\t\t\(ProjectText.quoted($0))," }
                    lines.append("\t);")
                } else {
                    lines.append("\t\(key) = \(ProjectText.quoted(value as? String ?? "\(value)"));")
                }
            }
            lines += ["};", "name = \(ProjectText.quoted(configuration.name));"]
            text.insertObject(Self.object(id, configuration.name, lines), id: id, isa: "XCBuildConfiguration")
            configurations.append((id, configuration.name))
        }
        let defaultName = model.string("defaultConfigurationName", of: model.string("buildConfigurationList", of: host.id) ?? "") ?? "Release"
        text.insertObject(Self.object(list, listComment, ["isa = XCConfigurationList;", "buildConfigurations = ("]
            + configurations.map { "\t\($0.id) /* \($0.name) */," }
            + [");", "defaultConfigurationIsVisible = 0;", "defaultConfigurationName = \(ProjectText.quoted(defaultName));"]),
                          id: list, isa: "XCConfigurationList")

        // The project lists the target; the host builds it first and embeds its product.
        if let projectObject = text.object(model.rootID) {
            text.append(target, comment: made.target, toArrayAt: text.array("targets", inDictionaryAt: projectObject.value))
        }
        if let tools = (model.dictionary("attributes", of: model.rootID)["TargetAttributes"] as? [String: Any])?[host.id] as? [String: Any],
           let created = tools["CreatedOnToolsVersion"] as? String,
           let attributes = text.entry(["attributes"], of: model.rootID) {
            let open = text.dictionary("TargetAttributes", inDictionaryAt: attributes.value)
            let indent = text.entries(open).first.map { text.indentation($0.line) } ?? text.innerIndentation(open)
            text.set(target, to: "{\n\(indent)\tCreatedOnToolsVersion = \(ProjectText.quoted(created));\n\(indent)}", inDictionaryAt: open)
        }
        embed(product: product, appex: appex, target: target, name: made.target, in: host)
        return true
    }

    /// The build settings of an extension's configuration `name`: its files, its bundle id under the app's, and
    /// the versions, team and Swift the host builds with.
    private func extensionSettings(_ made: AppExtension, host: AppTarget, configuration name: String, bundleID: String) -> [String: Any] {
        var hostSettings = model.projectSettings[name] ?? [:]
        for (key, value) in model.configurations(of: host.id).first(where: { $0.name == name })?.settings ?? [:] { hostSettings[key] = value }
        func copied(_ key: String, _ fallback: String?) -> String? { hostSettings[key] as? String ?? fallback }
        var settings: [String: Any] = [
            "CODE_SIGN_ENTITLEMENTS": "\(made.folder)/\(made.name).entitlements",
            "CODE_SIGN_STYLE": copied("CODE_SIGN_STYLE", "Automatic")!,
            "CURRENT_PROJECT_VERSION": copied("CURRENT_PROJECT_VERSION", "1")!,
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": "\(made.folder)/Info.plist",
            "INFOPLIST_KEY_CFBundleDisplayName": made.title,
            "INFOPLIST_KEY_NSHumanReadableCopyright": "",
            "IPHONEOS_DEPLOYMENT_TARGET": copied("IPHONEOS_DEPLOYMENT_TARGET", "17.0")!,
            "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
            "MARKETING_VERSION": copied("MARKETING_VERSION", "1.0")!,
            "PRODUCT_BUNDLE_IDENTIFIER": "\(bundleID).\(made.target)",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SDKROOT": "iphoneos",
            "SKIP_INSTALL": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SWIFT_VERSION": copied("SWIFT_VERSION", "5.0")!,
            "TARGETED_DEVICE_FAMILY": copied("TARGETED_DEVICE_FAMILY", "1,2")!,
        ]
        for key in ["DEVELOPMENT_TEAM", "SUPPORTED_PLATFORMS", "SUPPORTS_MACCATALYST", "SWIFT_STRICT_CONCURRENCY", "VALIDATE_PRODUCT"] {
            if let value = hostSettings[key] as? String { settings[key] = value }
        }
        return settings
    }

    /// Embeds an extension's product in `host`: its copy phase (made when the host has none), the build file,
    /// and the dependency that builds the extension first.
    private mutating func embed(product: String, appex: String, target: String, name: String, in host: AppTarget) {
        let phaseName = "Embed Foundation Extensions"
        let existing = embedPhases[host.id] ?? host.phases.first {
            model.isa($0) == "PBXCopyFilesBuildPhase" && "\(model.objects[$0]?["dstSubfolderSpec"] ?? "")" == "13"
        }
        let phase = existing ?? ids.make("embed \(host.name)")
        let phaseComment = existing.flatMap { model.string("name", of: $0) } ?? phaseName
        embedPhases[host.id] = phase
        let file = ids.make("embedded \(name)")
        text.insertObject("\t\t\(file) /* \(appex) in \(phaseComment) */ = {isa = PBXBuildFile; fileRef = \(product) /* \(appex) */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n",
                          id: file, isa: "PBXBuildFile")
        if existing == nil {
            text.insertObject(Self.object(phase, phaseName, [
                "isa = PBXCopyFilesBuildPhase;", "buildActionMask = 2147483647;", "dstPath = \"\";", "dstSubfolderSpec = 13;",
                "files = (", ");", "name = \"\(phaseName)\";", "runOnlyForDeploymentPostprocessing = 0;",
            ]), id: phase, isa: "PBXCopyFilesBuildPhase")
            if let hostObject = text.object(host.id) {
                text.append(phase, comment: phaseName, toArrayAt: text.array("buildPhases", inDictionaryAt: hostObject.value))
            }
        }
        if let phaseObject = text.object(phase) {
            text.append(file, comment: "\(appex) in \(phaseComment)", toArrayAt: text.array("files", inDictionaryAt: phaseObject.value))
        }
        let proxy = ids.make("proxy \(name)"), dependency = ids.make("dependency \(name)")
        text.insertObject(Self.object(proxy, "PBXContainerItemProxy", [
            "isa = PBXContainerItemProxy;", "containerPortal = \(model.rootID) /* Project object */;", "proxyType = 1;",
            "remoteGlobalIDString = \(target);", "remoteInfo = \(ProjectText.quoted(name));",
        ]), id: proxy, isa: "PBXContainerItemProxy")
        text.insertObject(Self.object(dependency, "PBXTargetDependency", [
            "isa = PBXTargetDependency;", "target = \(target) /* \(name) */;", "targetProxy = \(proxy) /* PBXContainerItemProxy */;",
        ]), id: dependency, isa: "PBXTargetDependency")
        if let hostObject = text.object(host.id) {
            text.append(dependency, comment: "PBXTargetDependency", toArrayAt: text.array("dependencies", inDictionaryAt: hostObject.value))
        }
    }

    /// Adds `item` to `group`'s children before `before` (the Products group, kept last), or last.
    private mutating func insert(_ item: String, comment: String, intoChildrenOf group: String, before: String?) {
        guard let object = text.object(group) else { return }
        let children = text.array("children", inDictionaryAt: object.value)
        if let before, let next = text.items(children).first(where: { $0.token == before }), text.lineStart(next.start) == next.line {
            text.insert(text.indentation(next.line) + "\(item) /* \(comment) */,\n", at: next.line)
        } else {
            text.append(item, comment: comment, toArrayAt: children)
        }
    }

    /// An object as Xcode writes it: `id /* comment */ = {`, its lines one tab deeper, `};`.
    static func object(_ id: String, _ comment: String, _ lines: [String]) -> String {
        "\t\t\(id) /* \(comment) */ = {\n" + lines.map { "\t\t\t" + $0 + "\n" }.joined() + "\t\t};\n"
    }

    // MARK: - Checking

    /// The edited text read back as a project: every object a reference names exists, and every target listed
    /// is a target. Throws `unreadable` naming the first that is not.
    func check() throws -> ProjectModel {
        let edited = try ProjectModel(text: text.text)
        var missing: [String] = []
        func visit(_ value: Any) {
            if let id = value as? String {
                if id.count == 24, id.allSatisfy({ $0.isHexDigit && !$0.isLowercase }), edited.objects[id] == nil { missing.append(id) }
            } else if let list = value as? [Any] { list.forEach(visit) }
            else if let dictionary = value as? [String: Any] { dictionary.forEach { visit($0.value) } }
        }
        for (_, object) in edited.objects { object.values.forEach(visit) }
        for target in edited.targets where edited.isa(target) != "PBXNativeTarget" && edited.isa(target) != "PBXAggregateTarget" {
            missing.append(target)
        }
        if let first = missing.first { throw PlatformError.unreadable("\(first) is named and not defined") }
        return edited
    }
}
