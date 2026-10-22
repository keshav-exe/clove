import Foundation

/// One install request: what to fetch, where it lives in the repo, and which agents get it.
struct PendingInstall: Identifiable, Hashable, Sendable {
    var id: String { skill.id }
    let skill: MarketplaceSkill
    /// Folder of SKILL.md inside the repository, when already known.
    let folderHint: String?
    let targets: Set<AgentTarget>
    /// A project folder to install into, or nil for everywhere.
    var project: URL?

    /// "Everywhere", or the project's folder name.
    var scopeTitle: String {
        project?.lastPathComponent ?? "Everywhere"
    }
}
