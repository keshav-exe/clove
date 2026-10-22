import Foundation
import Security

/// API keys in the login Keychain, one item per environment variable.
///
/// Clove made these items, so Clove reads them without asking. Anything else,
/// like the `security` tool a shell or MCP server uses, gets macOS's own
/// prompt first. That prompt is the on-demand access: nothing sits in a
/// dotfile in plain text.
enum SecretVault {
    static let service = "dev.clove.secrets"

    enum Failure: LocalizedError {
        case keychain(OSStatus)
        case invalidName(String)

        var errorDescription: String? {
            switch self {
            case .keychain(let status):
                (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)."
            case .invalidName(let name):
                "“\(name)” isn't a valid variable name. Use letters, digits, and underscores, like OPENAI_API_KEY."
            }
        }
    }

    static func names() throws -> [SecretItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw Failure.keychain(status) }

        return ((result as? [[String: Any]]) ?? [])
            .compactMap { attributes in
                guard let name = attributes[kSecAttrAccount as String] as? String else { return nil }
                return SecretItem(name: name, updatedAt: attributes[kSecAttrModificationDate as String] as? Date)
            }
            .sorted { $0.name < $1.name }
    }

    static func save(_ value: String, named name: String) throws {
        guard isValidName(name) else { throw Failure.invalidName(name) }
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]
        let data = Data(value.utf8)
        let status = SecItemAdd(item.merging([
            kSecValueData as String: data,
            kSecAttrLabel as String: "Clove: \(name)",
            kSecAttrDescription as String: "API key saved by Clove",
        ]) { $1 } as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let update = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard update == errSecSuccess else { throw Failure.keychain(update) }
        } else if status != errSecSuccess {
            throw Failure.keychain(status)
        }
    }

    static func value(named name: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { throw Failure.keychain(status) }
        return String(decoding: data, as: UTF8.self)
    }

    static func delete(named name: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.keychain(status) }
    }

    static func isValidName(_ name: String) -> Bool {
        guard let first = name.first, first.isLetter || first == "_" else { return false }
        return name.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }
    }

    // MARK: - Using a secret

    /// Reads one key at the moment it's needed. macOS asks first.
    static func lookup(_ name: String) -> String {
        "$(security find-generic-password -s \(service) -a \(name) -w)"
    }

    /// For a shell profile: sets the variable when a shell starts.
    static func exportLine(_ name: String) -> String {
        "export \(name)=\"\(lookup(name))\""
    }

    /// For an MCP server or any one command: the key exists only for that process.
    static func wrappedCommand(_ name: String, command: String = "npx -y your-mcp-server") -> String {
        "sh -c '\(name)=\"\(lookup(name))\" exec \(command)'"
    }
}
