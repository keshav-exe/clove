import Foundation

/// Lets one instruction file serve every agent. CLAUDE.md, AGENTS.md, and
/// GEMINI.md usually say the same thing; keeping three copies in step is the
/// chore. A relative link makes one file the source and the others follow it.
struct InstructionSharing: Sendable {
    let home: URL

    init(home: URL = .homeDirectory) {
        self.home = home
    }

    /// The file each agent reads, for the scope this resource lives in.
    func files(for resource: AgentResource) -> [AgentApp: URL] {
        if resource.scope.isGlobal {
            return [
                .claudeCode: home.appending(path: ".claude/CLAUDE.md"),
                .codex: home.appending(path: ".codex/AGENTS.md"),
                .gemini: home.appending(path: ".gemini/GEMINI.md"),
            ]
        }
        guard let project = projectFolder(of: resource) else { return [:] }
        return [
            .claudeCode: project.appending(path: "CLAUDE.md"),
            .shared: project.appending(path: "AGENTS.md"),
            .gemini: project.appending(path: "GEMINI.md"),
        ]
    }

    func state(of resource: AgentResource, for agent: AgentApp) -> ResourceSharing.State {
        guard let file = files(for: resource)[agent] else { return .absent }
        let original = resource.fileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        if file.standardizedFileURL.path(percentEncoded: false) == resource.fileURL.standardizedFileURL.path(percentEncoded: false) {
            return .original
        }
        let path = file.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path) else { return .absent }
        if file.resolvingSymlinksInPath().path(percentEncoded: false) == original { return .linked }
        // An empty file says nothing, so it may be replaced by a link.
        return isEmpty(file) ? .absent : .ownCopy
    }

    func share(_ resource: AgentResource, with agent: AgentApp) throws {
        guard let file = files(for: resource)[agent], state(of: resource, for: agent) == .absent else { return }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: file.path(percentEncoded: false)) {
            try fileManager.trashItem(at: file, resultingItemURL: nil)
        }
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let target = ResourceSharing.relativePath(from: file.deletingLastPathComponent(), to: resource.fileURL)
        try fileManager.createSymbolicLink(atPath: file.path(percentEncoded: false), withDestinationPath: target)
    }

    func unshare(_ resource: AgentResource, from agent: AgentApp) throws {
        guard let file = files(for: resource)[agent], state(of: resource, for: agent) == .linked else { return }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false))
        guard attributes[.type] as? FileAttributeType == .typeSymbolicLink else { return }
        try FileManager.default.removeItem(at: file)
    }

    private func projectFolder(of resource: AgentResource) -> URL? {
        var folder = resource.fileURL.deletingLastPathComponent()
        // .claude/CLAUDE.md and .github/copilot-instructions.md sit one level down.
        if [".claude", ".github"].contains(folder.lastPathComponent) {
            folder = folder.deletingLastPathComponent()
        }
        return folder
    }

    private func isEmpty(_ file: URL) -> Bool {
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
