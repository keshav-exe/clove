import Foundation
import Observation

@MainActor
@Observable
final class LicenseService {
    static let shared = LicenseService()

    private(set) var record: LicenseRecord?
    private(set) var status: LicenseStatus = .needsActivation
    private(set) var isValidating = false
    private(set) var lastError: String?

    var isUnlocked: Bool {
        #if DEBUG
        return true
        #else
        if case .unlocked = status { return true }
        return false
        #endif
    }

    private init() {
        record = LicenseKeychain.load()
        refreshStatus()
    }

    func bootstrap() async {
        refreshStatus()
        guard isUnlocked, let record else { return }
        await validateStoredLicense(record)
    }

    func activate(licenseKey raw: String) async {
        let licenseKey = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !licenseKey.isEmpty else {
            lastError = "Enter the license key from your purchase email."
            return
        }

        isValidating = true
        lastError = nil
        defer { isValidating = false }

        #if DEBUG
        if licenseKey.hasPrefix("DEBUG-") {
            let record = LicenseRecord(
                licenseKey: licenseKey,
                instanceID: "debug",
                instanceName: MachineIdentity.instanceName,
                customerEmail: nil,
                activatedAt: .now,
                lastValidatedAt: .now
            )
            persist(record)
            status = .unlocked
            return
        }
        #endif

        do {
            let record = try await LicenseAPI.activate(licenseKey: licenseKey)
            persist(record)
            status = .unlocked
        } catch {
            lastError = error.localizedDescription
            status = .invalid(error.localizedDescription)
        }
    }

    func deactivate() async {
        guard let record else { return }
        isValidating = true
        defer { isValidating = false }

        try? await LicenseAPI.deactivate(record: record)
        LicenseKeychain.delete()
        self.record = nil
        status = .needsActivation
    }

    private func validateStoredLicense(_ record: LicenseRecord) async {
        isValidating = true
        defer { isValidating = false }

        do {
            let updated = try await LicenseAPI.validate(record: record)
            persist(updated)
            status = .unlocked
        } catch {
            if isWithinOfflineGrace(record) {
                status = .unlocked
            } else {
                status = .expiredOffline
                lastError = "Could not reach the license server. Connect to the internet to verify your purchase."
            }
        }
    }

    private func persist(_ record: LicenseRecord) {
        self.record = record
        LicenseKeychain.save(record)
        refreshStatus()
    }

    private func refreshStatus() {
        guard let record else {
            status = .needsActivation
            return
        }

        if isWithinOfflineGrace(record) {
            status = .unlocked
        } else {
            status = .expiredOffline
        }
    }

    private func isWithinOfflineGrace(_ record: LicenseRecord) -> Bool {
        let grace = TimeInterval(LicenseConfiguration.offlineGraceDays * 24 * 60 * 60)
        return Date.now.timeIntervalSince(record.lastValidatedAt) <= grace
    }
}
