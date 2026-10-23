import Foundation

struct UpdateManifest: Identifiable, Hashable, Sendable {
    var id: String { version }
    let version: String
    let downloadURL: URL
    let releaseNotes: String?
}

/// Reads the latest GitHub release: its tag is the version, its DMG the download.
enum UpdateManifestLoader {
    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case htmlURL = "html_url"
            case assets
        }
    }

    static func load(from url: URL) async throws -> UpdateManifest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        let dmg = release.assets.first { $0.name.hasSuffix(".dmg") }?.browserDownloadURL
        return UpdateManifest(
            version: version,
            downloadURL: dmg ?? release.htmlURL,
            releaseNotes: release.body
        )
    }
}

enum VersionCompare {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
