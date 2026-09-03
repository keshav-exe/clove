import Foundation

enum ReleaseConfiguration {
    /// JSON manifest: `{ "version": "1.0", "download_url": "https://…/Clove.dmg" }`
    static let updateManifestURL: URL? = URL(string: "https://kshv.me/clove/appcast.json")
}
