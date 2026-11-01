//  WHAT: `Shared/AppDelegate.swift`: one file, a delegate a platform behind `#if os(iOS)` / `#elseif os(macOS)`,
//        doing only what the system hands the app. On iOS: launch (the appearance asked for) and a scene
//        delegate that hands opened URLs to `AppURL`; on macOS: launch (the click monitors asked for), opened
//        URLs handed to `AppURL`, and quitting with the last window.
//  PIN:  NO APP STATE. What the delegate hears goes out as a notification a view answers; nothing is kept but
//        the monitors' tokens.
//  PIN:  URLS ARRIVE AT THE SCENE ON iOS. `application(_:open:options:)` is not called for a scene-based app
//        (and is deprecated in iOS 26), so the delegate supplies a scene delegate, which SwiftUI calls beside
//        its own: the URL that launched the app and every one after.

import Foundation

enum AppDelegateFile {
    static let path = "Shared/AppDelegate.swift"

    /// Whether `text` is an AppDelegate.swift this agent wrote.
    static func isOurs(_ text: String) -> Bool { text.contains("/// The app's delegate on iOS") }

    /// What an AppDelegate.swift this agent wrote already does.
    static func features(in text: String) -> Set<PlatformDelegate> {
        var found: Set<PlatformDelegate> = []
        if text.contains("AppURL.open(") { found.insert(.urls) }
        if text.contains("UITextView.appearance()") { found.insert(.appearance) }
        if text.contains("addGlobalMonitorForEvents") { found.insert(.monitors) }
        return found
    }

    static func text(_ features: Set<PlatformDelegate>) -> String {
        let urls = features.contains(.urls), appearance = features.contains(.appearance), monitors = features.contains(.monitors)
        var lines = ["import Foundation", "", "#if os(iOS)", "import UIKit", ""]
        lines.append(urls ? "/// The app's delegate on iOS: launch, and the scene delegate that hands opened URLs to `AppURL`."
                          : "/// The app's delegate on iOS: launch.")
        lines += [
            "final class AppDelegate: NSObject, UIApplicationDelegate {",
            "    func application(_ application: UIApplication,",
            "                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {",
        ]
        if appearance {
            lines += ["        // Text views draw no background of their own, so a text editor shows the app's.",
                      "        UITextView.appearance().backgroundColor = .clear"]
        }
        lines += ["        return true", "    }"]
        if urls {
            lines += [
                "",
                "    func application(_ application: UIApplication,",
                "                     configurationForConnecting connectingSceneSession: UISceneSession,",
                "                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {",
                "        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)",
                "        configuration.delegateClass = SceneDelegate.self",
                "        return configuration",
                "    }",
                "",
                "    /// Hands every URL a window scene is asked to open to `AppURL`: the one that launched the app, and each after.",
                "    final class SceneDelegate: NSObject, UIWindowSceneDelegate {",
                "        func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {",
                "            for context in connectionOptions.urlContexts {",
                "                AppURL.open(context.url)",
                "            }",
                "        }",
                "",
                "        func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {",
                "            for context in URLContexts {",
                "                AppURL.open(context.url)",
                "            }",
                "        }",
                "    }",
            ]
        }
        lines += ["}", "#elseif os(macOS)", "import AppKit", ""]
        var about = ["launch"]
        if urls { about.append("opened URLs handed to `AppURL`") }
        if monitors { about.append("clicks told as `WindowClick`") }
        lines.append("/// The app's delegate on macOS: \(Self.list(about)).")
        lines.append("final class AppDelegate: NSObject, NSApplicationDelegate {")
        if monitors {
            lines += ["    /// The click monitors, held while the app runs.", "    private var monitors: [Any] = []", "",
                      "    func applicationDidFinishLaunching(_ notification: Notification) {", "        watchClicks()", "    }", ""]
        }
        if urls {
            lines += ["    func application(_ application: NSApplication, open urls: [URL]) {", "        for url in urls {",
                      "            AppURL.open(url)", "        }", "    }", ""]
        }
        lines += ["    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {", "        true", "    }"]
        if monitors {
            lines += [
                "",
                "    /// Tells `WindowClick.inside` for a click in one of the app's windows, `.outside` for a click anywhere else.",
                "    private func watchClicks() {",
                "        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { _ in",
                "            WindowClick.outside.post()",
                "        }) {",
                "            monitors.append(outside)",
                "        }",
                "        if let inside = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in",
                "            if event.window != nil {",
                "                WindowClick.inside.post()",
                "            }",
                "            return event",
                "        }) {",
                "            monitors.append(inside)",
                "        }",
                "    }",
            ]
        }
        lines += ["}", "#endif"]
        return lines.joined(separator: "\n") + "\n"
    }

    /// `a`, `a and b`, `a, b and c`.
    static func list(_ items: [String]) -> String {
        items.count <= 1 ? items.joined() : items.dropLast().joined(separator: ", ") + " and " + items.last!
    }
}
