import Foundation

/// An app target of the project: what it is built for, its configurations and the folders it builds.
struct AppTarget {
    let id: String
    let name: String
    /// Nil for a target built for several platforms at once.
    let platform: AppPlatform?
    /// Its configurations' ids and names, in order.
    let configurations: [(id: String, name: String)]
    /// Its first configuration's build settings, with the project's under them.
    let settings: [String: Any]
    /// Its synchronized folders: id, and path relative to the project's folder.
    let folders: [(id: String, path: String)]
    /// Its build phases' ids.
    let phases: [String]

    init(id: String, model: ProjectModel) {
        self.id = id
        name = model.string("name", of: id) ?? id
        let configurations = model.configurations(of: id)
        self.configurations = configurations.map { ($0.id, $0.name) }
        let first = configurations.first
        var merged = first.flatMap { model.projectSettings[$0.name] } ?? [:]
        for (key, value) in first?.settings ?? [:] { merged[key] = value }
        settings = merged
        folders = model.list("fileSystemSynchronizedGroups", of: id).map { ($0, model.path(of: $0)) }
        phases = model.list("buildPhases", of: id)
        platform = Self.platform(merged)
    }

    /// A setting's value as text; nil when it is not set.
    func setting(_ key: String) -> String? {
        if let text = settings[key] as? String { return text }
        if let list = settings[key] as? [String] { return list.joined(separator: " ") }
        return nil
    }

    /// The platform its settings build for.
    static func platform(_ settings: [String: Any]) -> AppPlatform? {
        let sdk = (settings["SDKROOT"] as? String ?? "").lowercased()
        let supported = (settings["SUPPORTED_PLATFORMS"] as? String ?? "").lowercased().split(separator: " ").map(String.init)
        let ios = supported.contains { $0.hasPrefix("iphone") } || sdk.hasPrefix("iphone")
        let mac = supported.contains("macosx") || sdk == "macosx"
        if ios && mac { return nil }
        if ios { return .iOS }
        if mac { return .macOS }
        if settings["IPHONEOS_DEPLOYMENT_TARGET"] != nil && settings["MACOSX_DEPLOYMENT_TARGET"] == nil { return .iOS }
        if settings["MACOSX_DEPLOYMENT_TARGET"] != nil && settings["IPHONEOS_DEPLOYMENT_TARGET"] == nil { return .macOS }
        return nil
    }

    /// The synchronized folder of this target that holds `path` (relative to the project), and `path` inside it.
    func folder(holding path: String) -> (id: String, path: String, inside: String)? {
        folders.filter { !$0.path.isEmpty && path.hasPrefix($0.path + "/") }.max { $0.path.count < $1.path.count }
            .map { ($0.id, $0.path, String(path.dropFirst($0.path.count + 1))) }
    }
}
