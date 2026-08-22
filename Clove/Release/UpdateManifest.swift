import Foundation

struct UpdateManifest: Codable, Identifiable, Hashable, Sendable {
    var id: String { version }
    let version: String
    let downloadURL: URL
    let releaseNotes: String?

    enum CodingKeys: String, CodingKey {
        case version
        case downloadURL = "download_url"
        case releaseNotes = "release_notes"
    }
}

enum UpdateManifestLoader {
    static func load(from url: URL) async throws -> UpdateManifest {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(UpdateManifest.self, from: data)
    }
}

enum VersionCompare {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }
}
