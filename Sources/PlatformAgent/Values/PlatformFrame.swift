import Foundation

/// What a run says as it goes.
public enum PlatformFrame: Sendable {
    /// The call was read and the project found: its name and app targets.
    case read(project: String, targets: [String])
    /// The files are written.
    case written(PlatformResult)

    public var result: PlatformResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
