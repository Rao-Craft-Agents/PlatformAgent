//  WHAT: The platform layer of an iOS + macOS Xcode project, as a Granite agent package: Info keys and URL
//        schemes, App Transport Security, entitlements, the app delegate, macOS menu commands, and app extensions
//        (an Action or Share extension with its app group and the app's inbox), done by editing the project.
//  IN:   Input: key lines, schemes, ATS, app groups, keychain groups, sandbox choices, command lines, extension
//        lines, what the delegate does, the app's name.
//  OUT:  PlatformResult: the files written (Swift, plists, the project file), a phrase a change, and notes.
//  PIN:  NO MODEL. Everything is made from the call and the project, the same way every time.
//  PIN:  IDEMPOTENT. Every edit looks before it adds: plists and entitlements are merged, project objects found by
//        name, settings compared; the same call twice writes nothing, a call with new keys adds only those.
//  PIN:  THE HOST'S FOLDER. The project is looked for in `directory`, else in the folder the host offers, else
//        the process's: a runner started anywhere still edits the project the host means.
//  PIN:  WHOLE OR NOTHING. Every reason a call cannot be done is said at once and nothing is written; the edited
//        project is read back before it lands, and every Swift file parses.

import Foundation
import GraniteAgents

public struct PlatformAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// One Info key a line: `camera: "takes photos of the dishes you cook"`, `category: lifestyle`,
        /// `queries: maps, comgooglemaps`, `bonjour: _recipes._tcp`, or an Info.plist key by its own name.
        public var keys: [String]?
        /// URL schemes that open the app: `recipes`.
        public var schemes: [String]?
        /// App Transport Security: HTTPS only, any host, or HTTP to `atsDomains`.
        public var ats: PlatformATS?
        /// The hosts `ats: domains` lets the app reach over HTTP, subdomains included.
        public var atsDomains: [String]?
        /// App groups the app and its extensions share: `group.com.example.recipes`.
        public var groups: [String]?
        /// Keychain access groups the app shares: `com.example.recipes.shared`.
        public var keychain: [String]?
        /// What the macOS app's sandbox lets it reach.
        public var sandbox: [PlatformSandbox]?
        /// One macOS menu command a line: `New Recipe ⌘N`, `Kitchen > Start Timer ⇧⌘T`.
        public var commands: [String]?
        /// One iOS app extension a line: `action SaveRecipe "Save to Recipes" accepts url,image`.
        public var extensions: [String]?
        /// What the app delegate does beside launching.
        public var delegate: [PlatformDelegate]?
        /// The app's name: which project, when the folder holds several; the project's name when left out.
        public var app: String?
        /// The host's folder.
        public var directory: String?

        public init(keys: [String]? = nil, schemes: [String]? = nil, ats: PlatformATS? = nil, atsDomains: [String]? = nil,
                    groups: [String]? = nil, keychain: [String]? = nil, sandbox: [PlatformSandbox]? = nil, commands: [String]? = nil,
                    extensions: [String]? = nil, delegate: [PlatformDelegate]? = nil, app: String? = nil, directory: String? = nil) {
            self.keys = keys; self.schemes = schemes; self.ats = ats; self.atsDomains = atsDomains; self.groups = groups
            self.keychain = keychain; self.sandbox = sandbox; self.commands = commands; self.extensions = extensions
            self.delegate = delegate; self.app = app; self.directory = directory
        }
    }

    public typealias Event = PlatformFrame
    public typealias Output = PlatformResult
    public typealias Compute = Void

    public static let word = "platform"
    public static let summary = "edits an iOS + macOS Xcode project's platform layer: Info keys and URL schemes, App Transport Security, entitlements, the app delegate, macOS menu commands and app extensions, merging into what is there."
    public static let fields = [
        "keys": "one Info key a line: `camera: \"why the app uses the camera\"`, `category: lifestyle`, `queries: maps, comgooglemaps`, `bonjour: _recipes._tcp`, or an Info.plist key by its own name",
        "schemes": "URL schemes that open the app, like `recipes`",
        "ats": "App Transport Security: default (HTTPS only), arbitrary (any host), domains (HTTP to atsDomains)",
        "atsDomains": "the hosts `ats: domains` lets the app reach over HTTP, like `kitchen.local`",
        "groups": "app groups the app and its extensions share, like `group.com.example.recipes`",
        "keychain": "keychain access groups the app shares, like `com.example.recipes.shared`",
        "sandbox": "what the macOS app's sandbox lets it reach: network, server, files, camera, photos, usb",
        "commands": "macOS menu commands, one a line: `New Recipe ⌘N`, `Refresh ⌘R`, `Kitchen > Start Timer ⇧⌘T`",
        "extensions": "iOS app extensions, one a line: `action SaveRecipe \"Save to Recipes\" accepts url,image` (action or share; accepts url, image, text)",
        "delegate": "what the app delegate does: urls (opened URLs to `.onOpenAppURL`), appearance (UIKit text views drawn clear), monitors (macOS clicks to `.onWindowClick`)",
        "app": "the app's name, only when the folder holds several Xcode projects",
    ]
    public static let guide = """
        Tag platform for what belongs to the platform rather than to a screen: Info keys, URL schemes, App Transport \
        Security, entitlements, the app delegate, macOS menu commands and iOS app extensions. It edits the Xcode \
        project in the folder (an app target for iOS and one for macOS, as granite makes it) and merges into what \
        is there: call it again to add more; the same call twice changes nothing. Give only the fields the request \
        needs. Info keys, one a line: `{"keys": ["camera: \\"takes photos of the dishes you cook\\"", "category: \
        lifestyle", "queries: maps, comgooglemaps"]}`; the words are camera, microphone, photos, photosAdd, \
        localNetwork, location, contacts, calendars, faceID, bluetooth, speech, tracking, category, displayName, \
        copyright, encryption, queries, bonjour, or an Info.plist key by its own name (`UIBackgroundModes: \
        [fetch]`). Schemes and ATS: `{"schemes": ["recipes"], "ats": "domains", "atsDomains": ["kitchen.local"]}`; \
        ats is default (HTTPS only), arbitrary (any host, for servers people choose) or domains. Entitlements: \
        `{"groups": ["group.com.example.recipes"], "keychain": ["com.example.recipes.shared"], "sandbox": \
        ["network", "files"]}`; sandbox is the macOS app's: network, server, files, camera, photos, usb. Menu \
        commands on macOS, one a line as `Menu > Title shortcut`: `{"commands": ["New Recipe ⌘N", "Refresh ⌘R", \
        "Kitchen > Start Timer ⇧⌘T"]}`; a title starting New, Open or Save goes in File, Show, Hide, Toggle or \
        Refresh in View, Find or Search in Edit, Go, Next or Previous in Go; name any other's menu. A view answers \
        a command with `.onAppCommand(.startTimer) { … }`. App extensions on iOS: `{"extensions": ["action \
        SaveRecipe \\"Save to Recipes\\" accepts url,image"]}` (action or share; accepts url, image, text) adds a \
        target embedded in the iOS app that shares an app group with it; the app takes what it leaves with \
        `.onSharedInbox { items in … }`. The delegate: `{"delegate": ["urls", "monitors"]}`; urls hands opened \
        URLs to `.onOpenAppURL { url in … }` (schemes and extensions turn it on), appearance draws UIKit text views \
        clear, monitors tells macOS clicks to `.onWindowClick { click in … }`. A request it cannot do is refused \
        with every reason and nothing is written: fix the call and send it again. Not for screens, services or \
        making the project (granite), nor for icons (assets).
        """

    public static func output(from events: [PlatformFrame]) -> PlatformResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<PlatformFrame, Error> {
        // The folder is the call's, else the host's (a host on the wire may give it only there), else the process's.
        var input = input
        if input.directory == nil { input.directory = context.host.directory }
        return AsyncThrowingStream { [input] continuation in
            let task = Task {
                do {
                    let result = try Self.write(input, note: context.host.note) { continuation.yield($0) }
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The whole call: the input read and checked, the project found, every change planned, then written.
    static func write(_ input: Input, note: @Sendable (String) -> Void, yield: (PlatformFrame) -> Void) throws -> PlatformResult {
        let request = PlatformRequest(input)
        guard !request.asksNothing else { throw PlatformError.nothing }
        guard request.reasons.isEmpty else { throw PlatformError.refused(request.reasons) }

        let files = AgentFiles(directory: input.directory)
        let project = try XcodeProject.find(in: files.root, app: request.app)
        yield(.read(project: project.name, targets: project.apps.map(\.name)))
        note("editing \(project.name).xcodeproj (\(project.apps.map(\.name).joined(separator: ", ")))")

        var plan = PlatformPlan(request: request, project: project)
        try plan.make()
        let changed = plan.planned.filter { file in (try? String(contentsOf: file.url, encoding: .utf8)) != file.text }
        guard !changed.isEmpty else {
            note("the project already has all of it")
            return PlatformResult(path: nil, paths: [], changes: [], notes: ["The project already has everything this call asks for."])
        }
        let written = try files.write(changed)
        note("wrote \(written.count) file\(written.count == 1 ? "" : "s")")
        return PlatformResult(path: written.first, paths: written, changes: plan.changes, notes: plan.notes)
    }
}
