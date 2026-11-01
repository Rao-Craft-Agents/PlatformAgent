import Foundation

/// What the macOS app's sandbox lets it reach.
public enum PlatformSandbox: String, Codable, Sendable, CaseIterable {
    /// Connections out: every app that talks to a server.
    case network
    /// Connections in: a local server or peer-to-peer.
    case server
    /// Files the person picks in an open or save panel, read and written.
    case files
    /// The camera.
    case camera
    /// The photo library.
    case photos
    /// USB devices.
    case usb
}
