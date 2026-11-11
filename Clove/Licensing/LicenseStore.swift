import Foundation
import Observation
import Security

/// Whether this copy of Clove is unlocked, and the activation behind it.
@MainActor
@Observable
final class LicenseStore {
    private(set) var license: License?
    private(set) var isWorking = false
    var failure: LicenseClient.Failure?

    init() {
        license = Self.load()
    }

    var isUnlocked: Bool {
        !LicenseConfiguration.isRequired || license != nil
    }

    func activate(key raw: String) async {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !isWorking else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }

        do {
            let instanceID = try await LicenseClient.activate(key: key, deviceName: Self.deviceName)
            let now = Date.now
            let license = License(key: key, instanceID: instanceID, activatedAt: now, lastValidatedAt: now)
            Self.save(license)
            self.license = license
        } catch {
            failure = error
        }
    }

    /// Frees this Mac's activation so the key can move to another Mac.
    func deactivate() async {
        guard let license, !isWorking else { return }
        isWorking = true
        failure = nil
        defer { isWorking = false }

        do {
            try await LicenseClient.deactivate(key: license.key, instanceID: license.instanceID)
            Self.remove()
            self.license = nil
        } catch {
            failure = error
        }
    }

    /// Checks the license again once a week. A refunded or deactivated key
    /// locks Clove; being offline doesn't, until the grace period runs out.
    func revalidateIfDue() async {
        guard LicenseConfiguration.isRequired, var license else { return }
        let age = Duration.seconds(Date.now.timeIntervalSince(license.lastValidatedAt))
        guard age > LicenseConfiguration.revalidateAfter else { return }

        do {
            if try await LicenseClient.validate(key: license.key, instanceID: license.instanceID) {
                license.lastValidatedAt = .now
                Self.save(license)
                self.license = license
            } else {
                Self.remove()
                self.license = nil
            }
        } catch {
            if age > LicenseConfiguration.offlineGrace {
                self.license = nil
            }
        }
    }

    private static var deviceName: String {
        Host.current().localizedName ?? "Mac"
    }

    // MARK: - Keychain

    private static let service = "dev.clove.license"
    private static let account = "license"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func load() -> License? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(License.self, from: data)
    }

    private static func save(_ license: License) {
        guard let data = try? JSONEncoder().encode(license) else { return }
        let update = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private static func remove() {
        SecItemDelete(query as CFDictionary)
    }
}
