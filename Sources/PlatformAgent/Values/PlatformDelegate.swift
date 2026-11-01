import Foundation

/// What the app delegate does beside launching.
public enum PlatformDelegate: String, Codable, Sendable, CaseIterable {
    /// Hands every URL the app is asked to open to the views (`AppURL`, `.onOpenAppURL`).
    case urls
    /// Sets UIKit appearance at launch: text views drawn clear, so text editors show the app's own background.
    case appearance
    /// Watches clicks on macOS: inside the app's windows or outside them (`WindowClick`, `.onWindowClick`).
    case monitors
}
