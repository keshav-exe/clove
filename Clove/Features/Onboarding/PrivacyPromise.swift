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
            title: "Your tags stay local",
            detail: "Saved in one JSON file inside Clove's Application Support folder."
        ),
        PrivacyPromise(
            symbolName: "key",
            title: "License checks only",
            detail: "The only network calls activate and verify your license. No analytics, no telemetry."
        ),
    ]
}
