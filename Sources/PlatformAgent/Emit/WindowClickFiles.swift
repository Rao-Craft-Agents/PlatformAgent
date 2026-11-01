//  WHAT: Clicks on macOS, as the app delegate's monitors hear them: `Shared/Utility/WindowClick.swift` (inside one
//        of the app's windows or outside them all, and the notification each is posted under) and
//        `Shared/Extensions/View+OnWindowClick.swift` (`.onWindowClick { click in }`).
//  PIN:  GRANITE'S NAMES. The notifications are named as Granite's `Granite.App.Interaction` names them, so a
//        window Granite routes (an alert that closes on a click outside) hears the same clicks, and the app
//        needs no import of Granite for it.

import Foundation

enum WindowClickFiles {
    static let typePath = "Shared/Utility/WindowClick.swift"
    static let modifierPath = "Shared/Extensions/View+OnWindowClick.swift"

    static let type = #"""
        import Foundation

        /// A click on macOS, in one of the app's windows or outside them all, as the app delegate's monitors hear it.
        /// The names are Granite's (`Granite.App.Interaction`), so a window Granite routes hears the same clicks.
        /// Views answer with `.onWindowClick { click in }`.
        enum WindowClick: String, CaseIterable, Sendable {
            /// In one of the app's windows.
            case inside
            /// Outside every window of the app.
            case outside

            /// The name the click is posted under.
            var notification: Notification.Name {
                switch self {
                case .inside: Notification.Name("nyc.stoic.Granite.App.Interaction.windowClickedInside")
                case .outside: Notification.Name("nyc.stoic.Granite.App.Interaction.windowClickedOutside")
                }
            }

            /// Tells the views and windows that answer clicks.
            func post() {
                NotificationCenter.default.post(name: notification, object: nil)
            }
        }

        """#

    static let modifier = #"""
        import SwiftUI

        extension View {
            /// Runs `action` with where each click landed, in one of the app's windows or outside them (macOS).
            func onWindowClick(perform action: @escaping (WindowClick) -> Void) -> some View {
                onReceive(NotificationCenter.default.publisher(for: WindowClick.inside.notification)) { _ in
                    action(.inside)
                }
                .onReceive(NotificationCenter.default.publisher(for: WindowClick.outside.notification)) { _ in
                    action(.outside)
                }
            }
        }

        """#
}
