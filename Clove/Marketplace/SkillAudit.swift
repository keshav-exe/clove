import Foundation

/// One partner's security verdict, as shown on a skills.sh page.
struct SkillAudit: Identifiable, Hashable, Sendable {
    enum Verdict: Sendable {
        case pass
        case warn
        case fail
        case unknown
    }

    var id: String { provider }
    let provider: String
    let status: String

    var verdict: Verdict {
        switch status.lowercased() {
        case "pass", "safe", "low risk": .pass
        case "warn", "med risk", "medium risk", "review": .warn
        case "fail", "high risk", "critical": .fail
        default: .unknown
        }
    }
}
