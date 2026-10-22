import Foundation

/// The few GitHub calls Clove needs. Raw files and tarballs come from hosts
/// without a rate limit; only the tree listing uses the 60-per-hour REST API.
struct GitHubClient: Sendable {
    struct TreeItem: Decodable, Hashable, Sendable {
        let path: String
        let type: String
        let sha: String
    }

    struct Tree: Decodable, Sendable {
        /// Hash of the repository root folder.
        let sha: String
        let tree: [TreeItem]

        /// Hash of the folder at `path`, or of the root for an empty path.
        func folderHash(at path: String) -> String? {
            if path.isEmpty { return sha }
            return tree.first { $0.type == "tree" && $0.path == path }?.sha
        }
    }

    enum Failure: LocalizedError {
        case rateLimited
        case unavailable(Int)

        var errorDescription: String? {
            switch self {
            case .rateLimited:
                "GitHub's hourly limit for anonymous requests was reached. Try again later."
            case .unavailable(let status):
                "GitHub returned an error (\(status))."
            }
        }
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Contents of a file on the default branch, or nil if it does not exist.
    func rawFile(repo: String, path: String) async throws -> String? {
        let url = SkillsDirectory.rawGitHub
            .appending(path: repo)
            .appending(path: "HEAD")
            .appending(path: path)
        let (data, response) = try await session.data(for: Self.request(url))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200 else { throw Failure.unavailable(status) }
        return String(decoding: data, as: UTF8.self)
    }

    /// Every path in the default branch with its git object hash.
    func tree(repo: String) async throws -> Tree {
        let url = SkillsDirectory.gitHubAPI
            .appending(path: "repos")
            .appending(path: repo)
            .appending(path: "git/trees/HEAD")
            .appending(queryItems: [URLQueryItem(name: "recursive", value: "1")])
        var request = Self.request(url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 403 || status == 429 { throw Failure.rateLimited }
        guard status == 200 else { throw Failure.unavailable(status) }

        return try JSONDecoder().decode(Tree.self, from: data)
    }

    /// Downloads the default branch as a gzipped tarball to a temporary file.
    func downloadTarball(repo: String) async throws -> URL {
        let url = SkillsDirectory.codeload
            .appending(path: repo)
            .appending(path: "tar.gz/HEAD")
        let (file, response) = try await session.download(for: Self.request(url))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.unavailable(status) }

        // URLSession may reclaim its download file, so keep our own copy.
        let kept = URL.temporaryDirectory.appending(path: "clove-\(UUID().uuidString).tar.gz")
        try FileManager.default.moveItem(at: file, to: kept)
        return kept
    }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("Clove/\(AppVersion.short)", forHTTPHeaderField: "User-Agent")
        return request
    }
}
