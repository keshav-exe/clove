import Foundation

/// What the skills.sh page for one skill says about it, beyond the listing.
struct SkillPageDetails: Hashable, Sendable {
    var description: String?
    var highlights: [String] = []
    var gitHubStars: String?
    var firstSeen: String?
    var audits: [SkillAudit] = []
    /// The rendered SKILL.md as plain paragraphs, used when GitHub has no copy.
    var renderedBody: [String] = []
}
