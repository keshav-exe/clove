import Foundation

struct ScanRoot: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let title: String
    let url: URL
    let exists: Bool
    let isCustom: Bool

    var path: String {
        url.path(percentEncoded: false)
    }

    static func agentRoots(home: URL = URL.homeDirectory) -> [ScanRoot] {
        let items: [(String, String)] = [
            ("Cursor", ".cursor/skills"),
            ("Cursor built-in", ".cursor/skills-cursor"),
            ("Cursor plugins", ".cursor/plugins/cache"),
            ("Claude", ".claude/skills"),
            ("Agents", ".agents/skills"),
            ("Codex", ".codex/skills"),
        ]
        return items.map { title, relative in
            make(title: title, url: home.appending(path: relative), isCustom: false)
        }
    }

    static func projectRoots(custom: [String], home: URL = URL.homeDirectory) -> [ScanRoot] {
        let conventional = ScanConfiguration.conventionalProjectFolders
            .map { home.appending(path: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
            .map { make(title: $0.lastPathComponent, url: $0, isCustom: false) }

        let added = custom.map { path in
            let url = URL(filePath: path)
            return make(title: url.lastPathComponent, url: url, isCustom: true)
        }

        return conventional + added
    }

    private static func make(title: String, url: URL, isCustom: Bool) -> ScanRoot {
        ScanRoot(
            title: title,
            url: url,
            exists: FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
            isCustom: isCustom
        )
    }
}
