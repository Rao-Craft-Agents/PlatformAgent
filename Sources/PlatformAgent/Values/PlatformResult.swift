import Foundation
import GraniteAgents

/// What a call answers: the files written, as absolute paths, what changed in the project, and what to know.
public struct PlatformResult: AgentAnswer, Equatable {
    /// The first file written.
    public var path: String?
    /// Every file written: Swift, plists and the project file. Empty when the project already had everything.
    public var paths: [String]
    /// One short phrase a change: `URL scheme recipes`, `extension ShareRecipeShare`.
    public var changes: [String]
    /// One sentence each: what the call assumed, and how the app answers what it added.
    public var notes: [String]

    public init(path: String?, paths: [String], changes: [String], notes: [String]) {
        self.path = path; self.paths = paths; self.changes = changes; self.notes = notes
    }
}
