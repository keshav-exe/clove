import Foundation

/// One install request: what to fetch, where it lives in the repo, and which agents get it.
struct PendingInstall: Identifiable, Hashable, Sendable {
    var id: String { skill.id }
    let skill: MarketplaceSkill
    /// Folder of SKILL.md inside the repository, when already known.
    let folderHint: String?
    let targets: Set<AgentTarget>
}
