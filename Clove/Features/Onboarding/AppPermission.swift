import Foundation

struct AppPermission: Identifiable, Hashable {
    var id: String { title }
    let symbolName: String
    let title: String
    let detail: String
    let isRequired: Bool

    static let all: [AppPermission] = [
        AppPermission(
            symbolName: "accessibility",
            title: "Accessibility",
            detail: "Lets Clove press Return or drag a skill into Cursor, Claude Code, VS Code, or Terminal.",
            isRequired: true
        ),
        AppPermission(
            symbolName: "folder.badge.plus",
            title: "Folder access",
            detail: "Asked only when you add a project folder. Agent folders in your home directory need no prompt.",
            isRequired: false
        ),
        AppPermission(
            symbolName: "internaldrive",
            title: "Never Full Disk Access",
            detail: "Clove reads SKILL.md files inside folders you already use for agent skills.",
            isRequired: false
        ),
    ]
}
