import Foundation

struct LicenseRecord: Codable, Equatable, Sendable {
    let licenseKey: String
    let instanceID: String
    let instanceName: String
    let customerEmail: String?
    let activatedAt: Date
    var lastValidatedAt: Date
}

enum LicenseStatus: Equatable, Sendable {
    case unlocked
    case needsActivation
    case expiredOffline
    case invalid(String)
}
