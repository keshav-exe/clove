import Foundation

struct PrivacyPromise: Identifiable, Hashable {
    var id: String { title }
    let symbolName: String
    let title: String
    let detail: String

    static let all: [PrivacyPromise] = [
        PrivacyPromise(
            symbolName: "lock.shield",
            title: "Skills never leave your Mac",
            detail: "Nothing is uploaded, synced, or analyzed in the cloud."
        ),
        PrivacyPromise(
            symbolName: "eye.slash",
            title: "Read-only",
            detail: "Clove reads the frontmatter of SKILL.md files. It never writes to them."
        ),
        PrivacyPromise(
            symbolName: "externaldrive.badge.checkmark",
            title: "Your groups stay local",
            detail: "Saved in one JSON file inside Clove's Application Support folder."
        ),
        PrivacyPromise(
            symbolName: "wifi.slash",
            title: "No analytics",
            detail: "Optional update checks are the only network call. No telemetry, no skill uploads."
        ),
    ]
}
