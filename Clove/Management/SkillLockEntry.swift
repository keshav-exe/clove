import Foundation

/// Where an installed skill came from, as recorded in `~/.agents/.skill-lock.json`.
struct SkillLockEntry: Hashable, Sendable {
    /// Folder name under `~/.agents/skills`.
    let name: String
    /// `owner/repo` for GitHub installs.
    let source: String
    let sourceType: String
    /// Path of SKILL.md inside the repository.
    let skillPath: String
    /// Git tree hash of the skill folder when it was installed or last updated.
    let folderHash: String
    let installedAt: Date?
    let updatedAt: Date?

    var isGitHub: Bool {
        sourceType == "github"
    }

    /// Path of the skill folder inside the repository. Empty for a root skill.
    var folderPath: String {
        (skillPath as NSString).deletingLastPathComponent
    }

    /// The skills.sh listing this entry was installed from.
    var marketplaceSkill: MarketplaceSkill {
        MarketplaceSkill(source: source, skillId: name, name: name, installs: 0)
    }
}
