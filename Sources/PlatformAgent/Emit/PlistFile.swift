//  WHAT: A property list file read as a dictionary and written back as XML, the way Xcode writes one (tabs,
//        keys in order), so a merged Info.plist or entitlements file reads as if made by hand.

import Foundation

enum PlistFile {
    /// The dictionary in the file at `url`: empty when there is no file, nil when the file is not a dictionary.
    static func read(_ url: URL) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return [:] }
        var format = PropertyListSerialization.PropertyListFormat.xml
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: &format)) as? [String: Any]
    }

    /// `dictionary` as an XML property list.
    static func xml(_ dictionary: [String: Any]) -> String {
        let data = (try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
