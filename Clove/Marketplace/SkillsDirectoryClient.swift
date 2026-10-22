import Foundation

/// Read-only access to skills.sh, plus finding each skill's SKILL.md on GitHub.
struct SkillsDirectoryClient: Sendable {
    enum Failure: LocalizedError {
        case unavailable(Int)
        case skillFileNotFound

        var errorDescription: String? {
            switch self {
            case .unavailable(let status):
                "skills.sh returned an error (\(status))."
            case .skillFileNotFound:
                "Couldn't find this skill's SKILL.md in its repository."
            }
        }
    }

    let session: URLSession
    let gitHub: GitHubClient

    init(session: URLSession = .shared) {
        self.session = session
        gitHub = GitHubClient(session: session)
    }

    @concurrent
    func leaderboard(_ feed: DiscoverFeed) async throws -> [MarketplaceSkill] {
        let html = try await text(at: SkillsDirectory.site.appending(path: feed.path))
        return try LeaderboardParser.skills(fromHTML: html)
    }

    @concurrent
    func search(_ query: String, limit: Int = 60) async throws -> [MarketplaceSkill] {
        let url = SkillsDirectory.site
            .appending(path: "api/search")
            .appending(queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
            ])
        let (data, response) = try await session.data(for: GitHubClient.request(url))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.unavailable(status) }

        struct Response: Decodable { let skills: [MarketplaceSkill] }
        return try JSONDecoder().decode(Response.self, from: data).skills
    }

    @concurrent
    func pageDetails(for skill: MarketplaceSkill) async throws -> SkillPageDetails {
        let html = try await text(at: skill.pageURL)
        return SkillPageParser.details(fromHTML: html)
    }

    /// Finds the skill's SKILL.md. Tries the common layouts on the raw host
    /// first, then falls back to one tree listing.
    @concurrent
    func skillFile(for skill: MarketplaceSkill, hint: String? = nil) async throws -> RemoteSkillFile {
        guard skill.isGitHub else { throw Failure.skillFileNotFound }

        let candidates = Self.candidatePaths(for: skill.skillId, hint: hint)
        let found = await withTaskGroup(of: (Int, RemoteSkillFile?).self) { group in
            for (rank, path) in candidates.enumerated() {
                group.addTask {
                    let markdown = try? await gitHub.rawFile(repo: skill.source, path: path)
                    return (rank, markdown.map { RemoteSkillFile(path: path, markdown: $0) })
                }
            }
            var hits: [(Int, RemoteSkillFile)] = []
            for await (rank, file) in group {
                if let file, Self.file(file, matches: skill) {
                    hits.append((rank, file))
                }
            }
            return hits.min { $0.0 < $1.0 }?.1
        }
        if let found { return found }

        let tree = try await gitHub.tree(repo: skill.source)
        for path in Self.skillPaths(in: tree.tree, matching: skill.skillId) {
            if let markdown = try await gitHub.rawFile(repo: skill.source, path: path) {
                let file = RemoteSkillFile(path: path, markdown: markdown)
                if Self.file(file, matches: skill) { return file }
            }
        }
        throw Failure.skillFileNotFound
    }

    static func candidatePaths(for skillId: String, hint: String?) -> [String] {
        var paths = [
            "skills/\(skillId)/SKILL.md",
            "\(skillId)/SKILL.md",
            ".claude/skills/\(skillId)/SKILL.md",
            ".agents/skills/\(skillId)/SKILL.md",
            "SKILL.md",
        ]
        if let hint {
            paths.removeAll { $0 == hint }
            paths.insert(hint, at: 0)
        }
        return paths
    }

    /// SKILL.md paths whose folder is named after the skill, shallowest first.
    static func skillPaths(in tree: [GitHubClient.TreeItem], matching skillId: String) -> [String] {
        tree
            .filter { $0.type == "blob" && $0.path.hasSuffix("/\(skillId)/SKILL.md") }
            .map(\.path)
            .sorted { $0.count < $1.count }
    }

    /// A root SKILL.md belongs to the skill only if its frontmatter says so.
    static func file(_ file: RemoteSkillFile, matches skill: MarketplaceSkill) -> Bool {
        let folder = (file.folderPath as NSString).lastPathComponent
        if folder == skill.skillId { return true }
        let name = SkillFrontmatterParser.parse(file.markdown).0.name
        return name == skill.skillId || name == skill.name
    }

    private func text(at url: URL) async throws -> String {
        let (data, response) = try await session.data(for: GitHubClient.request(url))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.unavailable(status) }
        return String(decoding: data, as: UTF8.self)
    }
}
