//  WHAT: A project as data, read with Foundation's own plist reader: its objects by id, for finding targets,
//        configurations, groups and folders. What a call changes is changed in the text (`ProjectText`); this is
//        read again from the edited text to check it.

import Foundation

struct ProjectModel {
    let objects: [String: [String: Any]]
    let rootID: String
    let objectVersion: Int

    init(text: String) throws {
        var format = PropertyListSerialization.PropertyListFormat.openStep
        let read = try? PropertyListSerialization.propertyList(from: Data(text.utf8), options: [], format: &format)
        guard let root = read as? [String: Any], let objects = root["objects"] as? [String: Any],
              let rootID = root["rootObject"] as? String else {
            throw PlatformError.unreadable("it is not a property list with objects and a root object")
        }
        self.objects = objects.compactMapValues { $0 as? [String: Any] }
        self.rootID = rootID
        objectVersion = Int(root["objectVersion"] as? String ?? "") ?? 0
    }

    func isa(_ id: String) -> String? { objects[id]?["isa"] as? String }
    func string(_ key: String, of id: String) -> String? { objects[id]?[key] as? String }
    func list(_ key: String, of id: String) -> [String] { objects[id]?[key] as? [String] ?? [] }
    func dictionary(_ key: String, of id: String) -> [String: Any] { objects[id]?[key] as? [String: Any] ?? [:] }

    var targets: [String] { list("targets", of: rootID) }
    var mainGroup: String? { string("mainGroup", of: rootID) }
    var productsGroup: String? { string("productRefGroup", of: rootID) }

    /// A target's configurations: id, name, build settings, in the list's order.
    func configurations(of target: String) -> [(id: String, name: String, settings: [String: Any])] {
        guard let list = string("buildConfigurationList", of: target) else { return [] }
        return self.list("buildConfigurations", of: list).map { id in
            (id, string("name", of: id) ?? id, dictionary("buildSettings", of: id))
        }
    }

    /// The project's own configurations' settings, by configuration name.
    var projectSettings: [String: [String: Any]] {
        var settings: [String: [String: Any]] = [:]
        for configuration in configurations(of: rootID) { settings[configuration.name] = configuration.settings }
        return settings
    }

    /// The group that lists `id` among its children.
    func parent(of id: String) -> String? {
        objects.first { entry in (entry.value["children"] as? [String])?.contains(id) == true }?.key
    }

    /// Where a group or folder lies, relative to the project's folder: its parents' paths joined to its own.
    func path(of id: String) -> String {
        var parts: [String] = [], current: String? = id, seen: Set<String> = []
        while let node = current, seen.insert(node).inserted {
            if let path = string("path", of: node), !path.isEmpty { parts.insert(path, at: 0) }
            if string("sourceTree", of: node) == "SOURCE_ROOT" { break }
            current = parent(of: node)
        }
        return parts.joined(separator: "/")
    }
}
