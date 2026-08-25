import Foundation

/// Single switchboard for alpha vs paid releases.
enum ReleaseConfiguration {
    /// Paid release: activation screen + Dodo license checks.
    static let requiresLicense = true

    static let channelName = "Release"

    static var isAlpha: Bool {
        !requiresLicense
    }

    /// JSON manifest: `{ "version": "0.2", "download_url": "https://…/Clove.dmg" }`
    static let updateManifestURL: URL? = URL(string: "https://kshv.me/clove/appcast.json")
}
