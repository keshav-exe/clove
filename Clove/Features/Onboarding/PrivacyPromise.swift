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
            symbolName: "hand.raised",
            title: "Changes only when you ask",
            detail: "Clove writes skill files only when you install, edit, or remove one. Anything replaced goes to the Trash."
        ),
        PrivacyPromise(
            symbolName: "externaldrive.badge.checkmark",
            title: "Your groups stay local",
            detail: "Saved in one file on this Mac."
        ),
        PrivacyPromise(
            symbolName: "wifi.slash",
            title: "No analytics",
            detail: "Discover only talks to skills.sh and GitHub while you browse or install. If you turn on plan limits, Clove asks Anthropic, OpenAI and Cursor how much you've used. Nothing else leaves your Mac."
        ),
    ]
}
