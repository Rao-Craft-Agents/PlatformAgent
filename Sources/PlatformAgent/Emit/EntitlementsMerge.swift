//  WHAT: What an app's entitlements gain from a call: the sandbox and what it lets the macOS app reach, app
//        groups, keychain sharing. Merged into the file, never replacing it; and, on macOS, the build settings
//        Xcode reads the same entitlements from, kept saying the same thing.
//  PIN:  THE FILE AND THE SETTINGS AGREE. Xcode merges `ENABLE_*` settings into the file's entitlements: a file
//        asking read-write beside a setting saying read-only signs both. So each sandbox key set here sets its
//        setting too.

import Foundation

struct EntitlementsMerge {
    /// Keys set to true: the sandbox and what it opens.
    var flags: [String] = []
    var groups: [String] = []
    var keychain: [String] = []

    static let groupsKey = "com.apple.security.application-groups"
    static let keychainKey = "keychain-access-groups"
    static let sandboxKey = "com.apple.security.app-sandbox"

    /// The entitlement each sandbox choice sets, and the macOS build setting that says the same.
    static func entitlement(_ choice: PlatformSandbox) -> (key: String, setting: String, value: String) {
        switch choice {
        case .network: return ("com.apple.security.network.client", "ENABLE_OUTGOING_NETWORK_CONNECTIONS", "YES")
        case .server: return ("com.apple.security.network.server", "ENABLE_INCOMING_NETWORK_CONNECTIONS", "YES")
        case .files: return ("com.apple.security.files.user-selected.read-write", "ENABLE_USER_SELECTED_FILES", "readwrite")
        case .camera: return ("com.apple.security.device.camera", "ENABLE_RESOURCE_ACCESS_CAMERA", "YES")
        case .photos: return ("com.apple.security.personal-information.photos-library", "ENABLE_RESOURCE_ACCESS_PHOTO_LIBRARY", "YES")
        case .usb: return ("com.apple.security.device.usb", "ENABLE_RESOURCE_ACCESS_USB", "YES")
        }
    }

    var asksAnything: Bool { !flags.isEmpty || !groups.isEmpty || !keychain.isEmpty }

    /// `existing` with the call's entitlements in it, and a phrase for each change.
    func apply(to existing: [String: Any]) -> (plist: [String: Any], changes: [String]) {
        var plist = existing
        var changes: [String] = []
        for flag in flags where plist[flag] as? Bool != true {
            plist[flag] = true
            if flag == "com.apple.security.files.user-selected.read-write" { plist["com.apple.security.files.user-selected.read-only"] = nil }
            changes.append(flag == Self.sandboxKey ? "App Sandbox" : "sandbox \(flag.split(separator: ".").suffix(2).joined(separator: "."))")
        }
        for (key, values, phrase) in [(Self.groupsKey, groups, "app group"), (Self.keychainKey, keychain, "keychain group")] {
            let current = plist[key] as? [String] ?? []
            let new = values.filter { !current.contains($0) }
            if !new.isEmpty {
                plist[key] = current + new
                changes += new.map { "\(phrase) \($0)" }
            }
        }
        return (plist, changes)
    }
}
