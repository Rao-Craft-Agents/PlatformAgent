//  WHAT: Fresh object ids for a project: 24 hex digits, made from what the object is (`target SaveRecipeAction`)
//        so the same edit of the same project makes the same ids, and never one the project already holds.

import CryptoKit
import Foundation

struct ObjectIDs {
    private var taken: Set<String>

    /// Every id `text` already holds.
    init(text: String) {
        var found: Set<String> = [], run: [UInt8] = []
        for byte in text.utf8 {
            if (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x46) { run.append(byte); continue }
            if run.count == 24 { found.insert(String(decoding: run, as: UTF8.self)) }
            run.removeAll(keepingCapacity: true)
        }
        if run.count == 24 { found.insert(String(decoding: run, as: UTF8.self)) }
        taken = found
    }

    /// An id for `role`, taken from now on.
    mutating func make(_ role: String) -> String {
        var attempt = 0
        while true {
            let digest = SHA256.hash(data: Data("platform \(role) \(attempt)".utf8))
            let id = digest.prefix(12).map { String(format: "%02X", $0) }.joined()
            if taken.insert(id).inserted { return id }
            attempt += 1
        }
    }
}
