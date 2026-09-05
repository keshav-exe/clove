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
        WhatsNewRelease(
            version: "0.2",
            title: "What's New in Clove",
            subtitle: "One skill, every source it is installed in.",
            symbolName: "link",
            features: [
                FeatureHighlight(
                    symbolName: "link",
                    title: "Linked Skills",
                    detail: "The same skill in Cursor, Claude, and other folders now appears once, with every source listed."
                ),
                FeatureHighlight(
                    symbolName: "tag",
                    title: "Source Badges",
                    detail: "See which agents a skill is installed in without opening the file."
                ),
                FeatureHighlight(
                    symbolName: "folder",
                    title: "Installed In",
                    detail: "Reveal or open each copy of a linked skill from the detail pane."
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.0",
            title: "What's New in Clove",
            subtitle: "Clove is free and open source.",
            symbolName: "sparkles",
            features: [
                FeatureHighlight(
                    symbolName: "gift",
                    title: "Free",
                    detail: "Every feature is unlocked. No license key, no account, no purchase."
                ),
                FeatureHighlight(
                    symbolName: "chevron.left.forwardslash.chevron.right",
                    title: "Open Source",
                    detail: "Clove is MIT licensed. Use it, fork it, and change it."
                ),
                FeatureHighlight(
                    symbolName: "lock.shield",
                    title: "Still on-device",
                    detail: "Skills never leave your Mac. Optional update checks are the only network call."
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.1",
            title: "What's New in Clove",
            subtitle: "Insert skills on Return, and a cleaner detail view.",
            symbolName: "sparkles",
            features: [
                FeatureHighlight(
                    symbolName: "text.cursor",
                    title: "Insert on Return",
                    detail: "Return in the panel types the highlighted skill into the prompt you came from. Option+Return still copies."
                ),
                FeatureHighlight(
                    symbolName: "folder",
                    title: "Add to Group",
                    detail: "One field with suggestions — type to create a group or pick an existing one."
                ),
                FeatureHighlight(
                    symbolName: "doc.text",
                    title: "Skill Detail",
                    detail: "The detail pane is easier to scan, with copyable references and cleaner file info."
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.2",
            title: "What's New in Clove",
            subtitle: "Arrow keys in the panel stay on one skill at a time.",
            symbolName: "arrow.up.arrow.down",
            features: [
                FeatureHighlight(
                    symbolName: "arrow.up.arrow.down",
                    title: "Panel Navigation",
                    detail: "Down and Up move to the next skill on screen, in list order — not search rank, and not the next group."
                ),
                FeatureHighlight(
                    symbolName: "shift",
                    title: "Shift+Arrow",
                    detail: "Shift+Up extends the selection instead of getting stuck after one row."
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.3",
            title: "What's New in Clove",
            subtitle: "The library is a real Mac app again.",
            symbolName: "menubar.rectangle",
            features: [
                FeatureHighlight(
                    symbolName: "menubar.rectangle",
                    title: "Menu Bar",
                    detail: "Opening the library puts Clove in the menu bar, with Settings and shortcuts."
                ),
                FeatureHighlight(
                    symbolName: "gearshape",
                    title: "Settings",
                    detail: "Open Settings from Clove → Settings, ⌘,, or the gear in the sidebar."
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
