import Foundation

enum ReleaseConfiguration {
    /// JSON manifest: `{ "version": "0.2", "download_url": "https://…/Clove.dmg" }`
    static let updateManifestURL: URL? = URL(string: "https://kshv.me/clove/appcast.json")
}
