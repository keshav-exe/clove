import Foundation

struct WhatsNewRelease: Identifiable, Hashable, Sendable {
    var id: String { version }
    let version: String
    let title: String
    let subtitle: String
    let symbolName: String
    let features: [FeatureHighlight]
}

enum WhatsNewCatalog {
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(
            version: "0.1",
            title: "What's New in Clove",
            subtitle: "Groups, a cleaner panel, and a more native Mac experience.",
            symbolName: "sparkles",
            features: [
                FeatureHighlight(
                    symbolName: "folder",
                    title: "Groups",
                    detail: "Organize skills into groups, pin them to the panel, and copy an entire group at once."
                ),
                FeatureHighlight(
                    symbolName: "doc.on.doc",
                    title: "Copy Group",
                    detail: "Copy every skill reference in a group from the panel footer, a group pill, or ⌘⇧C."
                ),
                FeatureHighlight(
                    symbolName: "square.grid.2x2",
                    title: "Native Design",
                    detail: "Sidebars, settings, and sheets now follow the same patterns as Apple’s own Mac apps."
                ),
                FeatureHighlight(
                    symbolName: "pin",
                    title: "Pin Groups",
                    detail: "Keep your favorite groups one tap away in the quick access panel."
                ),
            ]
        ),
    ]

    static var latest: WhatsNewRelease? {
        releases.last
    }

    static func release(for version: String) -> WhatsNewRelease? {
        releases.first { $0.version == version }
    }

    static func unseenRelease(lastSeenVersion: String?) -> WhatsNewRelease? {
        guard let latest else { return nil }
        guard lastSeenVersion != latest.version else { return nil }
        return latest
    }
}
