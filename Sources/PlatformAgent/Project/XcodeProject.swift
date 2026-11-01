//  WHAT: The Xcode project a call edits: found in the host's folder, read as text and as data, and its app
//        targets told apart by platform.

import Foundation

struct XcodeProject {
    /// The `.xcodeproj` folder, and its project file.
    let bundle: URL
    let file: URL
    /// The folder the project's paths start from.
    let folder: URL
    /// `Recipes`, for Recipes.xcodeproj.
    let name: String
    /// The project file as it was read.
    let text: String
    let model: ProjectModel
    /// Its application targets, in the project's order.
    let apps: [AppTarget]

    /// The project in `folder`: the one named `app` when there are several.
    static func find(in folder: URL, app: String?) throws -> XcodeProject {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let projects = names.filter { $0.hasSuffix(".xcodeproj") }.sorted()
        let chosen: String
        if let app, let named = projects.first(where: { $0.dropLast(10).lowercased() == app.lowercased() }) {
            chosen = named
        } else if projects.count == 1 {
            chosen = projects[0]
        } else if projects.isEmpty {
            throw PlatformError.refused(["there is no Xcode project in \(folder.path): make the app's project first"])
        } else {
            throw PlatformError.refused(["\(folder.path) holds \(projects.count) projects (\(projects.joined(separator: ", "))): name the app with `app`"])
        }
        let bundle = folder.appendingPathComponent(chosen, isDirectory: true)
        let file = bundle.appendingPathComponent("project.pbxproj")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else {
            throw PlatformError.refused(["\(chosen) has no project.pbxproj this agent can read"])
        }
        let model: ProjectModel
        do { model = try ProjectModel(text: text) } catch {
            throw PlatformError.refused(["\(chosen)/project.pbxproj does not read as a project"])
        }
        let apps = model.targets.filter { model.string("productType", of: $0) == "com.apple.product-type.application" }
            .map { AppTarget(id: $0, model: model) }
        return XcodeProject(bundle: bundle, file: file, folder: folder, name: String(chosen.dropLast(10)), text: text, model: model, apps: apps)
    }

    /// The app targets built for `platform`.
    func apps(for platform: AppPlatform) -> [AppTarget] { apps.filter { $0.platform == platform } }

    /// The target named `name`, of any kind.
    func target(named name: String) -> String? { model.targets.first { model.string("name", of: $0) == name } }

    /// The target an iOS extension is embedded in: the one named `<Name>-iOS` when there are several.
    var iOSHost: AppTarget? {
        let candidates = apps(for: .iOS)
        return candidates.first { $0.name.hasSuffix("-iOS") || $0.name.hasSuffix("iOS") } ?? candidates.first
    }
}
