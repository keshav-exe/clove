import Foundation

struct PrivacyPromise: Identifiable, Hashable {
    var id: String { title }
    let symbolName: String
    let title: String
    let detail: String

    static var all: [PrivacyPromise] {
        var items: [PrivacyPromise] = [
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
        ]

        if ReleaseConfiguration.requiresLicense {
            items.append(
                PrivacyPromise(
                    symbolName: "key",
                    title: "License checks only",
                    detail: "The only network calls activate and verify your license. No analytics, no telemetry."
                )
            )
        } else {
            items.append(
                PrivacyPromise(
                    symbolName: "wifi.slash",
                    title: "No network calls",
                    detail: "Clove works fully offline. No analytics, no telemetry, no skill uploads."
                )
            )
        }

        return items
    }
}
