import Foundation

/// A skill listed on skills.sh. The leaderboard and search endpoints return
/// slightly different shapes, so everything beyond the identity is optional.
struct MarketplaceSkill: Identifiable, Hashable, Sendable, Decodable {
    var id: String { source + "/" + skillId }

    /// `owner/repo` for GitHub skills, a domain for well-known sources.
    let source: String
    let skillId: String
    let name: String
    let installs: Int
    var weeklyInstalls: [Int] = []
    var isOfficial = false
    /// Hot feed only: installs this hour minus the same hour yesterday.
    var change: Int?

    init(
        source: String,
        skillId: String,
        name: String,
        installs: Int,
        weeklyInstalls: [Int] = [],
        isOfficial: Bool = false,
        change: Int? = nil
    ) {
        self.source = source
        self.skillId = skillId
        self.name = name
        self.installs = installs
        self.weeklyInstalls = weeklyInstalls
        self.isOfficial = isOfficial
        self.change = change
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        skillId = try container.decode(String.self, forKey: .skillId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? skillId
        installs = try container.decodeIfPresent(Int.self, forKey: .installs) ?? 0
        weeklyInstalls = try container.decodeIfPresent([Int].self, forKey: .weeklyInstalls) ?? []
        isOfficial = try container.decodeIfPresent(Bool.self, forKey: .isOfficial) ?? false
        change = try container.decodeIfPresent(Int.self, forKey: .change)
    }

    private enum CodingKeys: String, CodingKey {
        case source, skillId, name, installs, weeklyInstalls, isOfficial, change
    }

    var isGitHub: Bool {
        let parts = source.split(separator: "/")
        return parts.count == 2 && !parts[0].contains(".")
    }

    var owner: String {
        String(source.split(separator: "/").first ?? Substring(source))
    }

    var pageURL: URL {
        SkillsDirectory.site.appending(path: source).appending(path: skillId)
    }

    var repositoryURL: URL? {
        isGitHub ? URL(string: "https://github.com/\(source)") : nil
    }

    /// Matches a local skill by the folder or frontmatter name the CLI installs it under.
    func matches(_ skill: Skill) -> Bool {
        skill.directoryName == skillId || skill.name == skillId || skill.name == name
    }

    /// The `skills` CLI command, for people who prefer the terminal.
    var installCommand: String {
        let target = isGitHub ? "https://github.com/\(source)" : source
        return "npx skills add \(target) --skill \(skillId)"
    }
}
