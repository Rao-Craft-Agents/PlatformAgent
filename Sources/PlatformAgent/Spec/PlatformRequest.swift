//  WHAT: A call's input read and checked before the project is opened: every line parsed, every scheme, domain
//        and group made canonical, and every problem said at once.
//  PIN:  ALL REASONS, ONE ANSWER. A model fixes in one call what it is told in one answer, so nothing stops at
//        the first bad line.

import Foundation

struct PlatformRequest {
    var keys: [InfoKey] = []
    var schemes: [String] = []
    var ats: PlatformATS?
    var atsDomains: [String] = []
    var groups: [String] = []
    var keychain: [String] = []
    var sandbox: [PlatformSandbox] = []
    var commands: [MenuCommand] = []
    var extensions: [AppExtension] = []
    /// What the delegate does, when the call asks for it; nil when the call leaves the delegate alone.
    var delegate: [PlatformDelegate]?
    var app: String?
    /// Every reason something asked cannot be done.
    var reasons: [String] = []

    /// Whether the call asks for anything at all.
    var asksNothing: Bool {
        keys.isEmpty && schemes.isEmpty && ats == nil && atsDomains.isEmpty && groups.isEmpty && keychain.isEmpty
            && sandbox.isEmpty && commands.isEmpty && extensions.isEmpty && delegate == nil && reasons.isEmpty
    }

    init(_ input: PlatformAgent.Input) {
        app = input.app?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        if let app, app.range(of: #"^[A-Za-z0-9][A-Za-z0-9 _-]*$"#, options: .regularExpression) == nil {
            reasons.append("`\(app)` is not an app name: letters, digits, spaces, dashes")
        }

        for line in Self.lines(input.keys) {
            do {
                let key = try InfoKeyLine.parse(line)
                if keys.contains(where: { $0.key == key.key }) { reasons.append("\(key.key) is set twice in one call") }
                else { keys.append(key) }
            } catch { reasons += Self.reasons(error) }
        }
        for key in keys where key.key == "LSApplicationQueriesSchemes" {
            if case .list(let items) = key.value { for item in items where !Self.isScheme(item) { reasons.append("`\(item)` in queries is not a URL scheme") } }
        }
        for key in keys where key.key == "NSBonjourServices" {
            if case .list(let items) = key.value {
                for item in items where item.range(of: #"^_[A-Za-z0-9-]+\._(tcp|udp)$"#, options: .regularExpression) == nil {
                    reasons.append("`\(item)` is not a Bonjour service type: write it like _recipes._tcp")
                }
            }
        }

        for written in Self.lines(input.schemes) {
            var scheme = written
            for suffix in ["://", ":"] where scheme.hasSuffix(suffix) { scheme = String(scheme.dropLast(suffix.count)) }
            guard Self.isScheme(scheme) else { reasons.append("`\(written)` is not a URL scheme: a letter, then letters, digits, + . or -"); continue }
            if !schemes.contains(where: { $0.caseInsensitiveCompare(scheme) == .orderedSame }) { schemes.append(scheme) }
        }

        for written in Self.lines(input.atsDomains) {
            var host = written.lowercased()
            if let range = host.range(of: "://") { host = String(host[range.upperBound...]) }
            host = String(host.prefix { $0 != "/" && $0 != ":" })
            guard host.range(of: #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$"#, options: .regularExpression) != nil else {
                reasons.append("`\(written)` is not a domain: write the host alone, like recipes.example.com"); continue
            }
            if !atsDomains.contains(host) { atsDomains.append(host) }
        }
        ats = input.ats ?? (atsDomains.isEmpty ? nil : .domains)
        if ats == .domains, Self.lines(input.atsDomains).isEmpty {
            reasons.append("ats domains names no hosts: list them in atsDomains")
        }
        if ats == .default, !atsDomains.isEmpty {
            reasons.append("ats default takes no atsDomains: say ats domains to let those hosts load over HTTP")
        }

        for written in Self.lines(input.groups) {
            let group = written.hasPrefix("group.") || written.hasPrefix("$(") ? written : "group." + written
            guard group.range(of: #"^(group\.|\$\(TeamIdentifierPrefix\))[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil else {
                reasons.append("`\(written)` is not an app group: write it like group.com.example.recipes"); continue
            }
            if !groups.contains(group) { groups.append(group) }
        }
        for written in Self.lines(input.keychain) {
            let group = written.hasPrefix("$(") ? written : "$(AppIdentifierPrefix)" + written
            guard group.range(of: #"^\$\((AppIdentifierPrefix|TeamIdentifierPrefix)\)[A-Za-z0-9][A-Za-z0-9.-]*$"#, options: .regularExpression) != nil else {
                reasons.append("`\(written)` is not a keychain group: write it like com.example.recipes.shared"); continue
            }
            if !keychain.contains(group) { keychain.append(group) }
        }
        for choice in input.sandbox ?? [] where !sandbox.contains(choice) { sandbox.append(choice) }

        for line in Self.lines(input.commands) {
            do {
                let command = try MenuCommandLine.parse(line)
                if let twin = commands.first(where: { $0.name == command.name }) {
                    reasons.append("`\(twin.title)` and `\(command.title)` are one command twice")
                } else if let shortcut = command.shortcut, let twin = commands.first(where: { $0.shortcut == shortcut }) {
                    reasons.append("\(shortcut.symbol) is given to both \(twin.title) and \(command.title)")
                } else {
                    commands.append(command)
                }
            } catch { reasons += Self.reasons(error) }
        }
        for line in Self.lines(input.extensions) {
            do {
                let made = try ExtensionLine.parse(line)
                if extensions.contains(where: { $0.target == made.target }) { reasons.append("\(made.target) is named twice") }
                else { extensions.append(made) }
            } catch { reasons += Self.reasons(error) }
        }
        if let asked = input.delegate {
            var features: [PlatformDelegate] = []
            for feature in asked where !features.contains(feature) { features.append(feature) }
            delegate = features
        }
    }

    static func lines(_ values: [String]?) -> [String] {
        (values ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func isScheme(_ text: String) -> Bool {
        text.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*$"#, options: .regularExpression) != nil
    }

    static func reasons(_ error: Error) -> [String] {
        if case PlatformError.refused(let reasons) = error { return reasons }
        return ["\(error)"]
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
