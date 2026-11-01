import Foundation

/// What a call can say instead of writing.
public enum PlatformError: Error, Equatable, CustomStringConvertible {
    /// What the call asks that cannot be done, one sentence each, so all are fixed in one call.
    case refused([String])
    /// A call that asks for nothing.
    case nothing
    /// The project, once edited, no longer reads as a project: nothing was written.
    case unreadable(String)

    public var description: String {
        switch self {
        case .refused(let reasons) where reasons.count == 1: return "\(reasons[0]), so nothing was written"
        case .refused(let reasons):
            return "\(reasons.count) things cannot be done, so nothing was written:\n" + reasons.map { "- \($0)" }.joined(separator: "\n")
        case .nothing:
            return "the call asks for nothing: give keys, schemes, ats, groups, keychain, sandbox, commands, extensions or delegate"
        case .unreadable(let reason): return "the edited project does not read back (\(reason)), so nothing was written"
        }
    }
}
