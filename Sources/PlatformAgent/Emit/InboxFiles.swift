//  WHAT: The app's side of its extensions: `Shared/Utility/SharedInbox.swift` (what the extensions left in the app
//        group, read and cleared) and `Shared/Extensions/View+OnSharedInbox.swift` (`.onSharedInbox { items in }`,
//        run when the view appears and whenever the app comes forward).
//  PIN:  ONE FORMAT, BOTH SIDES. The extension's controller (`ExtensionFiles`) writes the entries this reads: an
//        array of `kind`, `value`, `source`, `date` under `SharedInbox` in the group's defaults; an image is a
//        file in the group container's `SharedInbox` folder, its entry naming the file.

import Foundation

enum InboxFiles {
    static let typePath = "Shared/Utility/SharedInbox.swift"
    static let modifierPath = "Shared/Extensions/View+OnSharedInbox.swift"
    /// The key the entries wait under, and the container folder images wait in.
    static let key = "SharedInbox"

    static func type(group: String, url: String) -> String {
        #"""
        import Foundation

        /// What the app's extensions leave for it in the app group: links, text and images shared from other apps.
        /// An extension opens the app with `url` once it has left something; the app takes what waits with
        /// `.onSharedInbox { items in }`, and each item is taken once.
        enum SharedInbox {
            /// The app group the app and its extensions share.
            static let group = "\#(group)"
            /// The URL an extension opens the app with.
            static let url = URL(string: "\#(url)")!
            /// Where the items wait in the group's defaults.
            static let key = "\#(key)"

            /// One thing shared into the app.
            struct Item: Hashable, Sendable {
                /// What was shared.
                enum Content: Hashable, Sendable {
                    /// A link.
                    case url(URL)
                    /// Text.
                    case text(String)
                    /// An image: a file in the app group's container, the app's to keep or delete.
                    case image(URL)
                }

                let content: Content
                /// The extension it came through, as its folder names it.
                let source: String
                /// When it was shared.
                let date: Date
            }

            /// The folder in the app group's container where extensions leave images.
            static var folder: URL? {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
                    .appendingPathComponent("\#(key)", isDirectory: true)
            }

            /// The items waiting, oldest first, from every extension or from the one named `source`; they wait no longer.
            static func take(from source: String? = nil) -> [Item] {
                guard let defaults = UserDefaults(suiteName: group) else { return [] }
                let entries = defaults.array(forKey: key) as? [[String: Any]] ?? []
                let taken = entries.filter { source == nil || $0["source"] as? String == source }
                guard !taken.isEmpty else { return [] }
                let kept = entries.filter { source != nil && $0["source"] as? String != source }
                if kept.isEmpty {
                    defaults.removeObject(forKey: key)
                } else {
                    defaults.set(kept, forKey: key)
                }
                return taken.compactMap(item)
            }

            /// An item from an entry an extension wrote; nil when the entry is not one.
            private static func item(_ entry: [String: Any]) -> Item? {
                guard let kind = entry["kind"] as? String, let value = entry["value"] as? String else { return nil }
                let source = entry["source"] as? String ?? ""
                let date = entry["date"] as? Date ?? Date()
                switch kind {
                case "url":
                    return URL(string: value).map { Item(content: .url($0), source: source, date: date) }
                case "text":
                    return Item(content: .text(value), source: source, date: date)
                case "image":
                    return folder.map { Item(content: .image($0.appendingPathComponent(value)), source: source, date: date) }
                default:
                    return nil
                }
            }
        }

        """#
    }

    static let modifier = #"""
        import SwiftUI
        #if os(iOS)
        import UIKit
        #elseif os(macOS)
        import AppKit
        #endif

        extension View {
            /// Runs `action` with what the app's extensions left (`SharedInbox`), from all of them or from the one named
            /// `source`, when this view appears and whenever the app comes forward; not when nothing waits.
            func onSharedInbox(from source: String? = nil, perform action: @escaping ([SharedInbox.Item]) -> Void) -> some View {
                #if os(iOS)
                let forward = UIApplication.didBecomeActiveNotification
                #else
                let forward = NSApplication.didBecomeActiveNotification
                #endif
                let deliver = {
                    let items = SharedInbox.take(from: source)
                    if !items.isEmpty {
                        action(items)
                    }
                }
                return onAppear(perform: deliver)
                    .onReceive(NotificationCenter.default.publisher(for: forward)) { _ in
                        deliver()
                    }
            }
        }

        """#
}
