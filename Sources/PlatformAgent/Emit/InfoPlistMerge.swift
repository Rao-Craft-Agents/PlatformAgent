//  WHAT: What a platform's Info.plist gains from a call: URL schemes, App Transport Security, and the keys that
//        are lists or that Xcode has no setting for. Merged into what the file holds, never replacing it.
//  PIN:  ADDED, NOT REPLACED. A scheme, a host or a list item already there stays; only `ats` says what ATS is,
//        since `default` exists to take exceptions out.

import Foundation

struct InfoPlistMerge {
    var schemes: [String] = []
    var ats: PlatformATS?
    var atsDomains: [String] = []
    /// The keys written into the file rather than as settings.
    var keys: [InfoKey] = []

    var asksAnything: Bool { !schemes.isEmpty || ats != nil || !keys.isEmpty }

    /// `existing` with the call's keys in it, and a phrase for each change.
    func apply(to existing: [String: Any]) -> (plist: [String: Any], changes: [String]) {
        var plist = existing
        var changes: [String] = []

        var types = plist["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let known = Set(types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }.map { $0.lowercased() })
        let missing = schemes.filter { !known.contains($0.lowercased()) }
        if !missing.isEmpty {
            if let index = types.firstIndex(where: { $0["CFBundleURLName"] as? String == "$(PRODUCT_BUNDLE_IDENTIFIER)" }) {
                types[index]["CFBundleURLSchemes"] = (types[index]["CFBundleURLSchemes"] as? [String] ?? []) + missing
            } else {
                types.append(["CFBundleTypeRole": "Editor", "CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleURLSchemes": missing])
            }
            plist["CFBundleURLTypes"] = types
            changes += missing.map { "URL scheme \($0)" }
        }

        var security = plist["NSAppTransportSecurity"] as? [String: Any] ?? [:]
        switch ats {
        case .default?:
            if plist["NSAppTransportSecurity"] != nil {
                plist["NSAppTransportSecurity"] = nil
                changes.append("ATS back to HTTPS only")
            }
        case .arbitrary?:
            if security["NSAllowsArbitraryLoads"] as? Bool != true {
                security["NSAllowsArbitraryLoads"] = true
                plist["NSAppTransportSecurity"] = security
                changes.append("ATS allows any host")
            }
        case .domains?:
            var domains = security["NSExceptionDomains"] as? [String: Any] ?? [:]
            var added: [String] = []
            for host in atsDomains where domains[host] == nil {
                domains[host] = ["NSExceptionAllowsInsecureHTTPLoads": true, "NSIncludesSubdomains": true]
                added.append(host)
            }
            let wasArbitrary = security["NSAllowsArbitraryLoads"] != nil
            security["NSAllowsArbitraryLoads"] = nil
            security["NSExceptionDomains"] = domains
            if !added.isEmpty || wasArbitrary {
                plist["NSAppTransportSecurity"] = security
                changes.append("ATS allows HTTP to " + (added.isEmpty ? atsDomains : added).joined(separator: ", "))
            }
        case nil:
            break
        }

        for key in keys {
            switch key.value {
            case .list(let items):
                let current = plist[key.key] as? [String] ?? []
                let new = items.filter { !current.contains($0) }
                if !new.isEmpty {
                    plist[key.key] = current + new
                    changes.append("\(key.key) \(new.joined(separator: ", "))")
                }
            case .string(let text):
                if plist[key.key] as? String != text { plist[key.key] = text; changes.append("Info \(key.key)") }
            case .boolean(let flag):
                if plist[key.key] as? Bool != flag { plist[key.key] = flag; changes.append("Info \(key.key)") }
            }
        }
        return (plist, changes)
    }
}
