import Foundation

/// Shares a slash command or subagent with other agents by linking to the
/// original file, so one edit reaches every agent. Never deletes another
/// agent's own copy: only links Clove made (or any link to this file) come out.
struct ResourceSharing: Sendable {
    enum State: Equatable, Sendable {
        /// This agent owns the original.
        case original
        /// A link to the original is in place.
        case linked
        /// This agent has a different file with the same name.
        case ownCopy
        case absent
    }

    let home: URL

    init(home: URL = .homeDirectory) {
        self.home = home
    }

    /// Agents that can use this kind of resource, with the folder each reads it from.
    func folders(for resource: AgentResource) -> [AgentApp: URL] {
        guard let root = root(of: resource) else { return [:] }
        let isGlobal = resource.scope.isGlobal
        switch resource.kind {
        case .commands:
            var folders: [AgentApp: URL] = [
                .claudeCode: root.appending(path: ".claude/commands"),
                .cursor: root.appending(path: ".cursor/commands"),
            ]
            // Codex reads saved prompts only from the home folder.
            if isGlobal {
                folders[.codex] = root.appending(path: ".codex/prompts")
            }
            return folders
        case .subagents:
            return [
                .claudeCode: root.appending(path: ".claude/agents"),
                .cursor: root.appending(path: ".cursor/agents"),
            ]
        default:
            return [:]
        }
    }

    func state(of resource: AgentResource, for agent: AgentApp) -> State {
        if agent == resource.agent { return .original }
        guard let url = linkURL(for: resource, agent: agent) else { return .absent }
        let fileManager = FileManager.default
        let path = url.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: path) || isSymbolicLink(url) else { return .absent }
        let original = resource.fileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        return url.resolvingSymlinksInPath().path(percentEncoded: false) == original ? .linked : .ownCopy
    }

    func share(_ resource: AgentResource, with agent: AgentApp) throws {
        guard let url = linkURL(for: resource, agent: agent) else { return }
        guard state(of: resource, for: agent) == .absent else { return }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Relative, so the link still works in a cloned repo or a moved home folder.
        let target = Self.relativePath(from: url.deletingLastPathComponent(), to: resource.fileURL)
        try fileManager.createSymbolicLink(atPath: url.path(percentEncoded: false), withDestinationPath: target)
    }

    func unshare(_ resource: AgentResource, from agent: AgentApp) throws {
        guard let url = linkURL(for: resource, agent: agent),
              state(of: resource, for: agent) == .linked,
              isSymbolicLink(url)
        else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Paths

    /// Where the link for `agent` would go, keeping any subfolder (Claude's
    /// `namespace:command` layout) and the file name.
    func linkURL(for resource: AgentResource, agent: AgentApp) -> URL? {
        let folders = folders(for: resource)
        guard let source = folders[resource.agent], let destination = folders[agent] else { return nil }
        let relative = SkillInstaller.relativePath(of: resource.fileURL, in: source)
        guard !relative.isEmpty else { return nil }
        return destination.appending(path: relative)
    }

    /// The home folder, or the project folder holding the agent's dot-folder.
    private func root(of resource: AgentResource) -> URL? {
        if resource.scope.isGlobal { return home }
        let components = resource.fileURL.pathComponents
        guard let index = components.lastIndex(where: { [".claude", ".cursor", ".codex"].contains($0) }) else { return nil }
        return URL(filePath: NSString.path(withComponents: Array(components[..<index])))
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    /// `../../.claude/commands/review.md` from one folder to a file.
    static func relativePath(from folder: URL, to file: URL) -> String {
        let from = folder.standardizedFileURL.pathComponents
        let to = file.standardizedFileURL.pathComponents
        var shared = 0
        while shared < min(from.count, to.count), from[shared] == to[shared] {
            shared += 1
        }
        let ups = Array(repeating: "..", count: from.count - shared)
        return (ups + to[shared...]).joined(separator: "/")
    }
}
