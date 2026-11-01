import Foundation

/// The platform an app target is built for.
enum AppPlatform: String, Sendable, CaseIterable, Comparable {
    case iOS
    case macOS

    /// The project's folder for this platform's own files (synchronized into its app target).
    var folder: String { rawValue }

    static func < (a: AppPlatform, b: AppPlatform) -> Bool { a.rawValue < b.rawValue }
}
