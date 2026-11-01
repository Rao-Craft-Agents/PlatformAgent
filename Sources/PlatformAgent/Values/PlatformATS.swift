import Foundation

/// What App Transport Security lets the app load.
public enum PlatformATS: String, Codable, Sendable, CaseIterable {
    /// HTTPS only, the system's rule: any exception an earlier call made is taken out.
    case `default`
    /// Any host, over HTTP too: for an app that talks to servers its people choose.
    case arbitrary
    /// HTTP to the hosts in `atsDomains` and their subdomains; HTTPS everywhere else.
    case domains
}
