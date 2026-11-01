//  WHAT: The app's side of URL opening: `Shared/Utility/AppURL.swift` (the URLs the delegate hears, kept until a
//        view takes them, and the notification that says one came) and `Shared/Extensions/View+OnOpenAppURL.swift`
//        (`.onOpenAppURL { url in }`).
//  PIN:  A URL WAITS FOR ITS VIEW. The URL that launches the app arrives before any view is on screen, so it is
//        kept until a view that answers appears; each URL is answered once.

import Foundation

enum AppURLFiles {
    static let typePath = "Shared/Utility/AppURL.swift"
    static let modifierPath = "Shared/Extensions/View+OnOpenAppURL.swift"

    static let type = #"""
        import Foundation

        /// The URLs the system asks the app to open (its scheme, a link, an extension handing over), as the app
        /// delegate hears them. Views answer them with `.onOpenAppURL { url in }`; each URL is answered once.
        @MainActor
        enum AppURL {
            /// Posted, with the URL as its object, when the app is asked to open one.
            nonisolated static let notification = Notification.Name("AppURL")

            /// URLs no view has answered yet: one that launched the app arrives before any view is on screen.
            private static var waiting: [URL] = []

            /// Hands `url` to the views that answer `.onOpenAppURL`.
            static func open(_ url: URL) {
                waiting.append(url)
                NotificationCenter.default.post(name: notification, object: url)
            }

            /// The URLs waiting, oldest first; none of them is handed out again.
            static func take() -> [URL] {
                defer { waiting.removeAll() }
                return waiting
            }
        }

        """#

    static let modifier = #"""
        import SwiftUI

        extension View {
            /// Runs `action` with each URL the app is asked to open (its scheme, a link, an extension handing over),
            /// the one that launched it too. Each URL is answered once, by the first view on screen that answers it,
            /// so answer them on the root view.
            func onOpenAppURL(perform action: @escaping (URL) -> Void) -> some View {
                onAppear {
                    AppURL.take().forEach(action)
                }
                .onReceive(NotificationCenter.default.publisher(for: AppURL.notification)) { _ in
                    AppURL.take().forEach(action)
                }
            }
        }

        """#
}
