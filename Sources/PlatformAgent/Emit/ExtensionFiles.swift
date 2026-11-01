//  WHAT: An app extension's own files, in its folder (`Action/SaveRecipe/`): its principal view controller in
//        UIKit, which reads what was shared, leaves it in the app group for the app (`SharedInbox`) and opens the
//        app by its URL scheme; its Info.plist (`NSExtension`: the extension point, the activation rule for what
//        it accepts, the principal class); and its entitlements (the app group).
//  PIN:  THE APP IS OPENED THROUGH THE RESPONDER CHAIN. An extension has no `UIApplication.shared`, and
//        `extensionContext.open` opens nothing from an Action or Share extension; the application object the
//        chain ends in can, with `open(_:options:completionHandler:)`, which is not barred from extensions.
//  PIN:  NO STORYBOARD. The principal class is named in Info.plist and lays out its own view, so the folder
//        holds only what the agent writes.

import Foundation

enum ExtensionFiles {
    static func controllerPath(_ made: AppExtension) -> String { "\(made.folder)/\(made.controller).swift" }
    static func infoPath(_ made: AppExtension) -> String { "\(made.folder)/Info.plist" }
    static func entitlementsPath(_ made: AppExtension) -> String { "\(made.folder)/\(made.name).entitlements" }

    static func info(_ made: AppExtension) -> [String: Any] {
        var rule: [String: Any] = [:]
        if made.accepts.contains(.url) { rule["NSExtensionActivationSupportsWebURLWithMaxCount"] = 1 }
        if made.accepts.contains(.image) { rule["NSExtensionActivationSupportsImageWithMaxCount"] = 1 }
        if made.accepts.contains(.text) { rule["NSExtensionActivationSupportsText"] = true }
        return ["NSExtension": [
            "NSExtensionAttributes": ["NSExtensionActivationRule": rule],
            "NSExtensionPointIdentifier": made.kind.point,
            "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).\(made.controller)",
        ] as [String: Any]]
    }

    static func entitlements(group: String) -> [String: Any] {
        [EntitlementsMerge.groupsKey: [group]]
    }

    static func controller(_ made: AppExtension, group: String, url: String) -> String {
        let nouns = made.accepts.map { $0 == .url ? "link" : $0.rawValue }
        let what = "the " + (nouns.count == 1 ? nouns[0] : nouns.dropLast().joined(separator: ", ") + " or " + nouns.last!)
        let title = made.title.replacingOccurrences(of: "\"", with: "\\\"")
        var lines = [
            "import UIKit",
            "import UniformTypeIdentifiers",
            "",
            "/// \u{201C}\(made.title)\u{201D}: takes \(what) shared to it, leaves it in the app group for the app (`SharedInbox`),",
            "/// and opens the app to take it.",
            "final class \(made.controller): UIViewController {",
            "    /// The app group the app takes its inbox from.",
            "    private let group = \"\(group)\"",
            "    /// The URL that brings the app forward.",
            "    private let appURL = URL(string: \"\(url)\")!",
            "    /// This extension, as the inbox names it.",
            "    private let source = \"\(made.name)\"",
            "    /// Whether the shared items are being handed over: once, when the view first appears.",
            "    private var handing = false",
            "",
            "    override func viewDidLoad() {",
            "        super.viewDidLoad()",
            "        view.backgroundColor = .systemBackground",
            "        view.accessibilityLabel = String(localized: \"\(title)\")",
            "        let spinner = UIActivityIndicatorView(style: .medium)",
            "        spinner.translatesAutoresizingMaskIntoConstraints = false",
            "        view.addSubview(spinner)",
            "        NSLayoutConstraint.activate([",
            "            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),",
            "            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),",
            "        ])",
            "        spinner.startAnimating()",
            "    }",
            "",
            "    override func viewDidAppear(_ animated: Bool) {",
            "        super.viewDidAppear(animated)",
            "        guard !handing else { return }",
            "        handing = true",
            "        Task { await handOver() }",
            "    }",
            "",
            "    /// Leaves what was shared in the inbox, opens the app, and closes.",
            "    private func handOver() async {",
            "        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }",
            "        var entries: [[String: Any]] = []",
            "        for provider in providers {",
            "            if let entry = await entry(from: provider) {",
            "                entries.append(entry)",
            "            }",
            "        }",
            "        if !entries.isEmpty, let defaults = UserDefaults(suiteName: group) {",
            "            defaults.set((defaults.array(forKey: \"\(InboxFiles.key)\") ?? []) + entries, forKey: \"\(InboxFiles.key)\")",
            "            openApp()",
            "        }",
            "        extensionContext?.completeRequest(returningItems: nil)",
            "    }",
            "",
            "    /// One inbox entry from what `provider` holds; nil when it holds nothing this extension accepts.",
            "    private func entry(from provider: NSItemProvider) async -> [String: Any]? {",
        ]
        if made.accepts.contains(.url) {
            lines += [
                "        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier), let url = await url(in: provider) {",
                "            return [\"kind\": \"url\", \"value\": url.absoluteString, \"source\": source, \"date\": Date()]",
                "        }",
            ]
        }
        if made.accepts.contains(.image) {
            lines += [
                "        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier), let name = await saveImage(from: provider) {",
                "            return [\"kind\": \"image\", \"value\": name, \"source\": source, \"date\": Date()]",
                "        }",
            ]
        }
        if made.accepts.contains(.text) {
            lines += [
                "        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), let text = await text(in: provider) {",
                "            return [\"kind\": \"text\", \"value\": text, \"source\": source, \"date\": Date()]",
                "        }",
            ]
        }
        lines += ["        return nil", "    }"]
        if made.accepts.contains(.url) {
            lines += [
                "",
                "    /// The link `provider` holds.",
                "    private func url(in provider: NSItemProvider) async -> URL? {",
                "        await withCheckedContinuation { continuation in",
                "            _ = provider.loadObject(ofClass: URL.self) { url, _ in",
                "                continuation.resume(returning: url)",
                "            }",
                "        }",
                "    }",
            ]
        }
        if made.accepts.contains(.image) {
            lines += [
                "",
                "    /// Saves the image `provider` holds into the app group's inbox folder, and answers the file's name.",
                "    private func saveImage(from provider: NSItemProvider) async -> String? {",
                "        let type = provider.registeredContentTypes.first { $0.conforms(to: .image) } ?? .image",
                "        let data: Data? = await withCheckedContinuation { continuation in",
                "            _ = provider.loadDataRepresentation(for: type) { data, _ in",
                "                continuation.resume(returning: data)",
                "            }",
                "        }",
                "        guard let data, let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?",
                "            .appendingPathComponent(\"\(InboxFiles.key)\", isDirectory: true) else { return nil }",
                "        let name = UUID().uuidString + \".\" + (type.preferredFilenameExtension ?? \"jpeg\")",
                "        do {",
                "            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)",
                "            try data.write(to: folder.appendingPathComponent(name))",
                "            return name",
                "        } catch {",
                "            return nil",
                "        }",
                "    }",
            ]
        }
        if made.accepts.contains(.text) {
            lines += [
                "",
                "    /// The text `provider` holds.",
                "    private func text(in provider: NSItemProvider) async -> String? {",
                "        await withCheckedContinuation { continuation in",
                "            _ = provider.loadObject(ofClass: String.self) { text, _ in",
                "                continuation.resume(returning: text)",
                "            }",
                "        }",
                "    }",
            ]
        }
        lines += [
            "",
            "    /// Brings the app forward by its URL scheme, through the application object the responder chain ends in.",
            "    private func openApp() {",
            "        var responder: UIResponder? = self",
            "        while let current = responder {",
            "            if let application = current as? UIApplication {",
            "                application.open(appURL, options: [:], completionHandler: nil)",
            "                return",
            "            }",
            "            responder = current.next",
            "        }",
            "    }",
            "}",
        ]
        return lines.joined(separator: "\n") + "\n"
    }
}
