import Foundation

/// One Info.plist key a call sets, read off a key line.
struct InfoKey: Equatable, Sendable {
    enum Value: Equatable, Sendable {
        case string(String)
        case boolean(Bool)
        case list([String])
    }

    /// As Info.plist names it: `NSCameraUsageDescription`.
    var key: String
    var value: Value
    /// The platforms whose app targets take it.
    var platforms: Set<AppPlatform>
    /// Written as the `INFOPLIST_KEY_<key>` build setting; otherwise into the platform's Info.plist.
    var isSetting: Bool

    /// The value as a build setting says it.
    var setting: String {
        switch value {
        case .string(let text): return text
        case .boolean(let flag): return flag ? "YES" : "NO"
        case .list(let items): return items.joined(separator: " ")
        }
    }

    /// The value as Info.plist holds it.
    var plist: Any {
        switch value {
        case .string(let text): return text
        case .boolean(let flag): return flag
        case .list(let items): return items
        }
    }
}
