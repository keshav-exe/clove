import Foundation

/// Finds instruction files, rules, commands, subagents, MCP servers, hooks,
/// and permissions for every agent, in the home folder and in each project.
/// Read-only: nothing here writes.
struct AgentConfigScanner: Sendable {
    let home: URL

    init(home: URL = .homeDirectory) {
        self.home = home
    }

    @concurrent
    func scan(projectContainers: [URL]) async -> [AgentResource] {
        var resources = globalResources()
        for project in projects(in: projectContainers) {
            resources += projectResources(in: project)
        }
        return resources.sorted { lhs, rhs in
            if lhs.scope != rhs.scope { return lhs.scope < rhs.scope }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Home folder

    private func globalResources() -> [AgentResource] {
        var resources: [AgentResource] = []

        let instructions: [(String, AgentApp)] = [
            (".claude/CLAUDE.md", .claudeCode),
            (".codex/AGENTS.md", .codex),
            (".gemini/GEMINI.md", .gemini),
            (".codeium/windsurf/memories/global_rules.md", .windsurf),
        ]
        for (path, agent) in instructions {
            resources += markdown(home.appending(path: path), kind: .instructions, agent: agent, scope: .global, name: displayName(path))
        }

        resources += markdownFiles(in: home.appending(path: ".claude/commands"), kind: .commands, agent: .claudeCode, scope: .global, namespaced: true)
        resources += markdownFiles(in: home.appending(path: ".cursor/commands"), kind: .commands, agent: .cursor, scope: .global)
        resources += markdownFiles(in: home.appending(path: ".codex/prompts"), kind: .commands, agent: .codex, scope: .global)
        resources += markdownFiles(in: home.appending(path: ".claude/agents"), kind: .subagents, agent: .claudeCode, scope: .global)
        resources += markdownFiles(in: home.appending(path: ".cursor/agents"), kind: .subagents, agent: .cursor, scope: .global)

        let claudeState = home.appending(path: ".claude.json")
        if let data = try? Data(contentsOf: claudeState) {
            resources += MCPConfigParser.servers(inJSON: data, file: claudeState, agent: .claudeCode, scope: .global)
            resources += claudeProjectServers(in: data, file: claudeState)
        }
        let jsonServers: [(String, AgentApp)] = [
            (".cursor/mcp.json", .cursor),
            (".gemini/settings.json", .gemini),
            ("Library/Application Support/Claude/claude_desktop_config.json", .claudeDesktop),
            (".codeium/windsurf/mcp_config.json", .windsurf),
        ]
        for (path, agent) in jsonServers {
            let file = home.appending(path: path)
            if let data = try? Data(contentsOf: file) {
                resources += MCPConfigParser.servers(inJSON: data, file: file, agent: agent, scope: .global)
            }
        }

        let codexConfig = home.appending(path: ".codex/config.toml")
        if let text = try? String(contentsOf: codexConfig, encoding: .utf8) {
            resources += MCPConfigParser.servers(inTOML: text, file: codexConfig, scope: .global)
            resources += HookConfigParser.codexNotify(inTOML: text, file: codexConfig)
        }

        resources += claudeSettings(home.appending(path: ".claude/settings.json"), scope: .global)
        let cursorHooks = home.appending(path: ".cursor/hooks.json")
        if let data = try? Data(contentsOf: cursorHooks) {
            resources += HookConfigParser.cursorHooks(inJSON: data, file: cursorHooks, scope: .global)
        }
        return resources
    }

    /// Servers added with `claude mcp add` inside a project live in ~/.claude.json.
    private func claudeProjectServers(in data: Data, file: URL) -> [AgentResource] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let projects = root["projects"] as? [String: Any]
        else { return [] }
        return projects.keys.flatMap { path in
            MCPConfigParser.servers(
                inJSON: data,
                file: file,
                agent: .claudeCode,
                scope: .project(URL(filePath: path).lastPathComponent),
                keyPath: ["projects", path]
            )
        }
    }

    // MARK: - Projects

    /// Each folder directly inside a project container, like ~/Developer/app.
    private func projects(in containers: [URL]) -> [URL] {
        let fileManager = FileManager.default
        return containers.flatMap { container in
            ((try? fileManager.contentsOfDirectory(
                at: container,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        }
    }

    private func projectResources(in project: URL) -> [AgentResource] {
        let scope = ResourceScope.project(project.lastPathComponent)
        var resources: [AgentResource] = []

        let instructions: [(String, AgentApp)] = [
            ("CLAUDE.md", .claudeCode),
            ("CLAUDE.local.md", .claudeCode),
            (".claude/CLAUDE.md", .claudeCode),
            ("AGENTS.md", .shared),
            ("GEMINI.md", .gemini),
            (".github/copilot-instructions.md", .copilot),
        ]
        for (path, agent) in instructions {
            resources += markdown(project.appending(path: path), kind: .instructions, agent: agent, scope: scope, name: displayName(path))
        }

        resources += markdownFiles(in: project.appending(path: ".cursor/rules"), kind: .rules, agent: .cursor, scope: scope, extensions: ["mdc", "md"])
        resources += cursorRulesLegacy(project.appending(path: ".cursorrules"), scope: scope)
        resources += markdown(project.appending(path: ".windsurfrules"), kind: .rules, agent: .windsurf, scope: scope, name: ".windsurfrules", allowAnyExtension: true)
        resources += markdownFiles(in: project.appending(path: ".windsurf/rules"), kind: .rules, agent: .windsurf, scope: scope)
        resources += markdownFiles(in: project.appending(path: ".github/instructions"), kind: .rules, agent: .copilot, scope: scope)

        resources += markdownFiles(in: project.appending(path: ".claude/commands"), kind: .commands, agent: .claudeCode, scope: scope, namespaced: true)
        resources += markdownFiles(in: project.appending(path: ".cursor/commands"), kind: .commands, agent: .cursor, scope: scope)
        resources += markdownFiles(in: project.appending(path: ".claude/agents"), kind: .subagents, agent: .claudeCode, scope: scope)

        for (path, agent) in [(".mcp.json", AgentApp.claudeCode), (".cursor/mcp.json", .cursor)] {
            let file = project.appending(path: path)
            if let data = try? Data(contentsOf: file) {
                resources += MCPConfigParser.servers(inJSON: data, file: file, agent: agent, scope: scope)
            }
        }

        resources += claudeSettings(project.appending(path: ".claude/settings.json"), scope: scope)
        resources += claudeSettings(project.appending(path: ".claude/settings.local.json"), scope: scope)
        let cursorHooks = project.appending(path: ".cursor/hooks.json")
        if let data = try? Data(contentsOf: cursorHooks) {
            resources += HookConfigParser.cursorHooks(inJSON: data, file: cursorHooks, scope: scope)
        }
        return resources
    }

    // MARK: - Helpers

    private func claudeSettings(_ file: URL, scope: ResourceScope) -> [AgentResource] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return HookConfigParser.claudeHooks(inJSON: data, file: file, scope: scope)
            + PermissionsParser.permissions(inJSON: data, file: file, scope: scope)
    }

    /// `.cursorrules` is a single file in old projects and a folder in some newer ones.
    private func cursorRulesLegacy(_ url: URL, scope: ResourceScope) -> [AgentResource] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) else { return [] }
        if isDirectory.boolValue {
            return markdownFiles(in: url, kind: .rules, agent: .cursor, scope: scope)
        }
        return markdown(url, kind: .rules, agent: .cursor, scope: scope, name: ".cursorrules", allowAnyExtension: true)
    }

    private func markdown(
        _ url: URL,
        kind: ResourceKind,
        agent: AgentApp,
        scope: ResourceScope,
        name: String? = nil,
        allowAnyExtension: Bool = false
    ) -> [AgentResource] {
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
            !isDirectory.boolValue
        else { return [] }
        return MarkdownResourceParser.resource(at: url, kind: kind, agent: agent, scope: scope, name: name).map { [$0] } ?? []
    }

    /// Markdown files in a folder. Claude Code namespaces commands in
    /// subfolders as `folder:name`.
    private func markdownFiles(
        in folder: URL,
        kind: ResourceKind,
        agent: AgentApp,
        scope: ResourceScope,
        namespaced: Bool = false,
        extensions: Set<String> = ["md"]
    ) -> [AgentResource] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var resources: [AgentResource] = []
        while let file = enumerator.nextObject() as? URL {
            guard extensions.contains(file.pathExtension.lowercased()) else { continue }
            var name: String?
            if namespaced {
                let relative = SkillInstaller.relativePath(of: file.deletingPathExtension(), in: folder)
                name = relative.replacing("/", with: ":")
            }
            if kind == .commands || kind == .rules {
                name = name ?? file.deletingPathExtension().lastPathComponent
            }
            resources += markdown(file, kind: kind, agent: agent, scope: scope, name: name)
        }
        return resources
    }

    private func displayName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
