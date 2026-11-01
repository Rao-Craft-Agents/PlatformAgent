//  WHAT: What a call does to a project, worked out before anything is written: the files with their new text
//        (Swift, plists, the project file), a phrase for each change, and the notes the model reads.
//  PIN:  MERGED, NOT REPLACED. Info.plists and entitlements gain what the call asks and keep what they hold;
//        menu commands and delegate duties add to what an earlier call wrote. The same call twice plans no file.
//  PIN:  EVERY REFUSAL AT ONCE. What the project cannot take (no macOS target for a menu, no iOS target for an
//        extension) is said before any file is planned, so nothing is half done.

import Foundation

struct PlatformPlan {
    let request: PlatformRequest
    let project: XcodeProject
    var editor: ProjectEditor
    /// Files to write: absolute URL and text.
    private(set) var planned: [(url: URL, text: String)] = []
    private(set) var changes: [String] = []
    private(set) var notes: [String] = []

    init(request: PlatformRequest, project: XcodeProject) {
        self.request = request
        self.project = project
        editor = ProjectEditor(project: project)
    }

    var appName: String { request.app ?? project.name }

    func url(_ path: String) -> URL { project.folder.appendingPathComponent(path) }

    // MARK: - The call

    mutating func make() throws {
        try check()
        let host = project.iOSHost
        let bundleID = host?.setting("PRODUCT_BUNDLE_IDENTIFIER")
        var schemes = request.schemes
        var extensionGroup: String?
        var openURL: String?
        if !request.extensions.isEmpty, let host, let bundleID {
            let existing = readEntitlements(of: host)[EntitlementsMerge.groupsKey] as? [String]
            if let group = request.groups.first ?? existing?.first { extensionGroup = group } else {
                extensionGroup = "group." + bundleID
                notes.append("No app group was given: the extensions share \(extensionGroup!) with the app.")
            }
            let known = (readInfo(of: host)["CFBundleURLTypes"] as? [[String: Any]])?.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
            if let scheme = request.schemes.first ?? known?.first {
                openURL = scheme + "://inbox"
            } else {
                let derived = appName.lowercased().filter { $0.isLetter || $0.isNumber }
                let scheme = derived.first?.isLetter == true ? derived : "app" + derived
                schemes.append(scheme)
                openURL = scheme + "://inbox"
                notes.append("No URL scheme was given: the extensions open the app with \(scheme)://.")
            }
        }
        applyKeys()
        applyInfoPlists(schemes: schemes)
        applyEntitlements(extensionGroup: extensionGroup)
        applyDelegate()
        applyCommands()
        if let host, let bundleID, let group = extensionGroup, let openURL { applyExtensions(host: host, bundleID: bundleID, group: group, url: openURL) }
        if editor.changed {
            _ = try editor.check()
            planned.append((project.file, editor.text.text))
        }
        noteFoldersNotBuilt()
    }

    /// What the project cannot take, every reason at once.
    private func check() throws {
        var reasons: [String] = []
        let iOS = project.apps(for: .iOS), macOS = project.apps(for: .macOS)
        if project.apps.isEmpty { reasons.append("\(project.name).xcodeproj has no app target") }
        for target in project.apps where target.platform == nil {
            reasons.append("\(target.name) builds for iOS and macOS in one target: this agent edits a project with an app target for each")
        }
        if !request.extensions.isEmpty {
            if iOS.isEmpty { reasons.append("app extensions are iOS's, and the project has no iOS app target") }
            else if project.iOSHost?.setting("PRODUCT_BUNDLE_IDENTIFIER") == nil {
                reasons.append("\(project.iOSHost!.name) has no PRODUCT_BUNDLE_IDENTIFIER for its extensions to sit under")
            }
            if project.model.objectVersion < 77 {
                reasons.append("the project is objectVersion \(project.model.objectVersion): an extension is added as a synchronized folder, which takes Xcode 16's format (77)")
            }
            for made in request.extensions {
                if let existing = project.target(named: made.target), project.model.string("productType", of: existing) != "com.apple.product-type.app-extension" {
                    reasons.append("the project has a target named \(made.target) that is not an app extension: name the extension otherwise")
                }
            }
        }
        if !request.sandbox.isEmpty, macOS.isEmpty { reasons.append("sandbox entitlements are macOS's, and the project has no macOS app target") }
        if !request.commands.isEmpty, macOS.isEmpty { reasons.append("menu commands are macOS's, and the project has no macOS app target") }
        if request.delegate?.contains(.monitors) == true, macOS.isEmpty { reasons.append("click monitors are macOS's, and the project has no macOS app target") }
        if request.delegate?.contains(.appearance) == true, iOS.isEmpty { reasons.append("appearance is UIKit's, and the project has no iOS app target") }
        let commands = mergedCommands()
        var seen: [Shortcut: String] = [:]
        for command in commands {
            guard let shortcut = command.shortcut else { continue }
            if let other = seen[shortcut] { reasons.append("\(shortcut.symbol) is \(other)'s already: give \(command.title) another shortcut") }
            seen[shortcut] = command.title
        }
        let menus = Set(commands.map(\.menu))
        if menus.count > 10 { reasons.append("the commands name \(menus.count) menus, and a menu bar holds 10 of the app's own: place them in fewer") }
        guard reasons.isEmpty else { throw PlatformError.refused(reasons) }
    }

    // MARK: - Info keys

    private mutating func applyKeys() {
        for key in request.keys where key.isSetting {
            var changed = false
            for platform in key.platforms.sorted() {
                for target in project.apps(for: platform) where editor.set("INFOPLIST_KEY_" + key.key, key.setting, on: target) { changed = true }
            }
            if changed { changes.append("Info \(key.key)") }
        }
    }

    /// The Info.plist a target reads beside its generated one, relative to the project; nil when it names one
    /// this agent cannot place (a path through a setting).
    private func infoPath(of target: AppTarget, platform: AppPlatform) -> String? {
        guard let set = target.setting("INFOPLIST_FILE") else { return "\(platform.folder)/Info.plist" }
        let path = set.replacingOccurrences(of: "$(SRCROOT)/", with: "").replacingOccurrences(of: "$(PROJECT_DIR)/", with: "")
        return path.contains("$(") ? nil : path
    }

    private func readInfo(of target: AppTarget) -> [String: Any] {
        guard let platform = target.platform, let path = infoPath(of: target, platform: platform) else { return [:] }
        return PlistFile.read(url(path)) ?? [:]
    }

    private mutating func applyInfoPlists(schemes: [String]) {
        for platform in AppPlatform.allCases {
            let merge = InfoPlistMerge(schemes: schemes, ats: request.ats, atsDomains: request.atsDomains,
                                       keys: request.keys.filter { !$0.isSetting && $0.platforms.contains(platform) })
            guard merge.asksAnything else { continue }
            let byPath = Dictionary(grouping: project.apps(for: platform)) { infoPath(of: $0, platform: platform) ?? "" }
            for (path, targets) in byPath.sorted(by: { $0.key < $1.key }) {
                guard !path.isEmpty else {
                    notes.append("\(targets.map(\.name).joined(separator: ", ")) names its Info.plist through a build setting: add the keys there by hand.")
                    continue
                }
                guard let existing = PlistFile.read(url(path)) else {
                    notes.append("\(path) is not a property list this agent can read, so its keys were left alone.")
                    continue
                }
                let (plist, phrases) = merge.apply(to: existing)
                guard !phrases.isEmpty else { continue }
                planned.append((url(path), PlistFile.xml(plist)))
                for phrase in phrases where !changes.contains(phrase) { changes.append(phrase) }
                for target in targets {
                    if target.setting("INFOPLIST_FILE") == nil { editor.set("INFOPLIST_FILE", path, on: target) }
                    editor.keepOut(path, of: target)
                }
            }
        }
    }

    // MARK: - Entitlements

    private func entitlementsPath(of target: AppTarget, platform: AppPlatform) -> String {
        let set = target.setting("CODE_SIGN_ENTITLEMENTS")?.replacingOccurrences(of: "$(SRCROOT)/", with: "")
        return set.flatMap { $0.contains("$(") ? nil : $0 } ?? "\(platform.folder)/\(appName).entitlements"
    }

    private func readEntitlements(of target: AppTarget) -> [String: Any] {
        guard let platform = target.platform else { return [:] }
        return PlistFile.read(url(entitlementsPath(of: target, platform: platform))) ?? [:]
    }

    private mutating func applyEntitlements(extensionGroup: String?) {
        for platform in AppPlatform.allCases {
            for target in project.apps(for: platform) {
                var merge = EntitlementsMerge(groups: request.groups, keychain: request.keychain)
                if platform == .iOS, let extensionGroup, !merge.groups.contains(extensionGroup) { merge.groups.append(extensionGroup) }
                var settings: [(String, String)] = []
                if platform == .macOS {
                    let sandboxed = !request.sandbox.isEmpty || target.setting("ENABLE_APP_SANDBOX") == "YES"
                    if sandboxed, merge.asksAnything || !request.sandbox.isEmpty { merge.flags.append(EntitlementsMerge.sandboxKey) }
                    if !request.sandbox.isEmpty { settings.append(("ENABLE_APP_SANDBOX", "YES")) }
                    for choice in request.sandbox {
                        let entitlement = EntitlementsMerge.entitlement(choice)
                        merge.flags.append(entitlement.key)
                        settings.append((entitlement.setting, entitlement.value))
                    }
                }
                guard merge.asksAnything else { continue }
                let path = entitlementsPath(of: target, platform: platform)
                guard let existing = PlistFile.read(url(path)) else {
                    notes.append("\(path) is not a property list this agent can read, so its entitlements were left alone.")
                    continue
                }
                let (plist, phrases) = merge.apply(to: existing)
                if !phrases.isEmpty { planned.append((url(path), PlistFile.xml(plist))) }
                if target.setting("CODE_SIGN_ENTITLEMENTS") == nil { editor.set("CODE_SIGN_ENTITLEMENTS", path, on: target) }
                for (key, value) in settings { editor.set(key, value, on: target) }
                for phrase in phrases where !changes.contains(phrase) { changes.append(phrase) }
            }
        }
    }

    // MARK: - The delegate

    private mutating func applyDelegate() {
        // A scheme or an extension is a URL the app must answer: it turns on urls beside whatever else is asked.
        let implied: Set<PlatformDelegate> = request.schemes.isEmpty && request.extensions.isEmpty ? [] : [.urls]
        guard request.delegate != nil || !implied.isEmpty else { return }
        let asked = Set(request.delegate ?? []).union(implied)
        let existing = (try? String(contentsOf: url(AppDelegateFile.path), encoding: .utf8)) ?? ""
        let had = AppDelegateFile.features(in: existing)
        let features = had.union(asked)
        planned.append((url(AppDelegateFile.path), AppDelegateFile.text(features)))
        if !AppDelegateFile.isOurs(existing), existing.split(separator: "\n").count > 30 {
            notes.append("\(AppDelegateFile.path), which this agent had not written, was replaced: what it did besides is in the project's history.")
        }
        if features.contains(.urls) {
            planned.append((url(AppURLFiles.typePath), AppURLFiles.type))
            planned.append((url(AppURLFiles.modifierPath), AppURLFiles.modifier))
        }
        if features.contains(.monitors) {
            planned.append((url(WindowClickFiles.typePath), WindowClickFiles.type))
            planned.append((url(WindowClickFiles.modifierPath), WindowClickFiles.modifier))
        }
        let added = PlatformDelegate.allCases.filter { features.contains($0) && !had.contains($0) }
        if !added.isEmpty { changes.append("delegate " + added.map(\.rawValue).joined(separator: ", ")) }
        if added.contains(.urls) { notes.append("Answer opened URLs with `.onOpenAppURL { url in … }` on the root view.") }
        if added.contains(.monitors) { notes.append("Answer clicks with `.onWindowClick { click in … }` (.inside or .outside).") }
    }

    // MARK: - Menu commands

    /// The commands an earlier call wrote, with this call's added (a title said again takes its new place).
    private func mergedCommands() -> [MenuCommand] {
        let existing = CommandFiles.commands(in: (try? String(contentsOf: url(CommandFiles.typePath), encoding: .utf8)) ?? "")
        var merged = existing.map { old in request.commands.first { $0.name == old.name } ?? old }
        merged += request.commands.filter { new in !existing.contains { $0.name == new.name } }
        return merged
    }

    private mutating func applyCommands() {
        guard !request.commands.isEmpty else { return }
        let existing = CommandFiles.commands(in: (try? String(contentsOf: url(CommandFiles.typePath), encoding: .utf8)) ?? "")
        let commands = mergedCommands()
        let menu = (try? String(contentsOf: url(CommandFiles.menuPath), encoding: .utf8)) ?? ""
        if !CommandFiles.isOurs(menu), menu.split(separator: "\n").count > 30 {
            notes.append("\(CommandFiles.menuPath), which this agent had not written, was replaced: what it did besides is in the project's history.")
        }
        planned.append((url(CommandFiles.typePath), CommandFiles.type(commands)))
        planned.append((url(CommandFiles.modifierPath), CommandFiles.modifier))
        planned.append((url(CommandFiles.menuPath), CommandFiles.menu(commands)))
        let new = request.commands.filter { !existing.contains($0) }
        if !new.isEmpty {
            changes += new.map { "menu \($0.line)" }
            notes.append("Answer menu commands with `.onAppCommand(.\(new[0].name)) { … }` where their state is.")
        }
        if CommandFiles.replacesNewWindow(commands), !CommandFiles.replacesNewWindow(existing),
           let taker = commands.first(where: { $0.menu == "File" && $0.shortcut?.symbol == "⌘N" }) {
            notes.append("\(taker.title) takes ⌘N, so it replaces File › New Window.")
        }
    }

    // MARK: - Extensions

    private mutating func applyExtensions(host: AppTarget, bundleID: String, group: String, url openURL: String) {
        for made in request.extensions {
            planned.append((url(ExtensionFiles.controllerPath(made)), ExtensionFiles.controller(made, group: group, url: openURL)))
            planned.append((url(ExtensionFiles.infoPath(made)), PlistFile.xml(ExtensionFiles.info(made))))
            planned.append((url(ExtensionFiles.entitlementsPath(made)), PlistFile.xml(ExtensionFiles.entitlements(group: group))))
            if editor.add(made, host: host, bundleID: bundleID) {
                changes.append("extension \(made.target) (\(made.kind.rawValue): \(made.accepts.map(\.rawValue).joined(separator: ", ")))")
            }
        }
        let hadInbox = FileManager.default.fileExists(atPath: url(InboxFiles.typePath).path)
        planned.append((url(InboxFiles.typePath), InboxFiles.type(group: group, url: openURL)))
        planned.append((url(InboxFiles.modifierPath), InboxFiles.modifier))
        if !hadInbox { notes.append("Take what the extensions leave with `.onSharedInbox { items in … }` on the root view.") }
    }

    // MARK: - Folders

    /// One note for the Swift files written where a target that needs them does not build (a project without
    /// synchronized folders there): they must be added to the targets in Xcode.
    private mutating func noteFoldersNotBuilt() {
        var unbuilt: [[String]: [String]] = [:], order: [[String]] = []
        for (fileURL, _) in planned where fileURL.pathExtension == "swift" {
            let path = String(fileURL.path.dropFirst(project.folder.path.count + 1))
            let needing: [AppTarget]
            if path.hasPrefix("Shared/") { needing = project.apps }
            else if path.hasPrefix("macOS/") { needing = project.apps(for: .macOS) }
            else { continue }
            let missing = needing.filter { $0.folder(holding: path) == nil }.map(\.name)
            guard !missing.isEmpty else { continue }
            if unbuilt[missing] == nil { order.append(missing) }
            unbuilt[missing, default: []].append(path)
        }
        for targets in order {
            let files = unbuilt[targets]!
            notes.append("\(AppDelegateFile.list(files)) \(files.count == 1 ? "is" : "are") not in a folder \(AppDelegateFile.list(targets)) "
                + "\(targets.count == 1 ? "builds" : "build"): add \(files.count == 1 ? "it" : "them") to \(targets.count == 1 ? "the target" : "the targets") in Xcode.")
        }
    }
}
