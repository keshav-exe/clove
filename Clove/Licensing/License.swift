import Foundation

/// An activation of a license key on this Mac.
struct License: Codable, Equatable, Sendable {
    let key: String
    let instanceID: String
    let activatedAt: Date
    var lastValidatedAt: Date

    /// The end of the key, enough to recognise it in Settings.
    var maskedKey: String {
        "••••" + key.suffix(4)
    }
}
