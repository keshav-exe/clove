import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class SecretsStore {
    private(set) var items: [SecretItem] = []
    private(set) var findings: [PlaintextSecretFinder.Finding] = []
    private(set) var loadError: String?
    var selection: SecretItem.ID?
    var isAdding = false
    var failure: ManagerFailure?

    func load() {
        do {
            items = try SecretVault.names()
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        findings = PlaintextSecretFinder.findings(in: PlaintextSecretFinder.profiles())
    }

    func save(_ value: String, named name: String) -> Bool {
        do {
            try SecretVault.save(value, named: name)
            load()
            selection = name
            return true
        } catch {
            failure = ManagerFailure(title: "Couldn't save \(name)", error: error)
            return false
        }
    }

    func delete(_ name: String) {
        do {
            try SecretVault.delete(named: name)
            if selection == name { selection = nil }
            load()
        } catch {
            failure = ManagerFailure(title: "Couldn't delete \(name)", error: error)
        }
    }

    /// The value, after Touch ID or the Mac's password. Nil if the person cancels.
    func reveal(_ name: String) async -> String? {
        let context = LAContext()
        do {
            guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "show \(name)") else { return nil }
            return try SecretVault.value(named: name)
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel {
            return nil
        } catch {
            failure = ManagerFailure(title: "Couldn't read \(name)", error: error)
            return nil
        }
    }

    func moveToKeychain(_ chosen: [PlaintextSecretFinder.Finding]) {
        do {
            try PlaintextSecretFinder.move(chosen)
            load()
        } catch {
            failure = ManagerFailure(title: "Couldn't move the keys", error: error)
        }
    }
}
