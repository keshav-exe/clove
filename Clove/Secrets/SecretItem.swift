import Foundation

/// A key's name and when it last changed. The value stays in the Keychain.
struct SecretItem: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let updatedAt: Date?
}
