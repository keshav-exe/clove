import Foundation

/// Single switchboard for alpha vs paid releases.
enum ReleaseConfiguration {
    /// Alpha: free, no activation screen. Paid release: set to `true`.
    static let requiresLicense = false

    static let channelName = "Alpha"

    static var isAlpha: Bool {
        !requiresLicense
    }

    /// JSON manifest: `{ "version": "0.2", "download_url": "https://…/Clove.dmg" }`
    static let updateManifestURL: URL? = URL(string: "https://kshv.me/clove/appcast.json")
}
