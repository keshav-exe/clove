import Foundation
import Testing
@testable import Clove

struct SharingTests {
    private func makeHome() throws -> URL {
        let home = URL.temporaryDirectory.appending(path: "clove-share-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func sharesACommandByLinking() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = home.appending(path: ".claude/commands/review.md")
        try write("---\ndescription: Review\n---\nReview the diff.", to: file)
        let resource = try #require(MarkdownResourceParser.resource(at: file, kind: .commands, agent: .claudeCode, scope: .global))

        let sharing = ResourceSharing(home: home)
        #expect(sharing.state(of: resource, for: .cursor) == .absent)
        try sharing.share(resource, with: .cursor)
        #expect(sharing.state(of: resource, for: .cursor) == .linked)

        let link = home.appending(path: ".cursor/commands/review.md")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path(percentEncoded: false)) == "../../.claude/commands/review.md")

        try sharing.unshare(resource, from: .cursor)
        #expect(sharing.state(of: resource, for: .cursor) == .absent)
        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func leavesAnotherAgentsOwnCopyAlone() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let file = home.appending(path: ".claude/agents/reviewer.md")
        try write("---\nname: reviewer\n---\nA", to: file)
        try write("---\nname: reviewer\n---\nB", to: home.appending(path: ".cursor/agents/reviewer.md"))
        let resource = try #require(MarkdownResourceParser.resource(at: file, kind: .subagents, agent: .claudeCode, scope: .global))

        let sharing = ResourceSharing(home: home)
        #expect(sharing.state(of: resource, for: .cursor) == .ownCopy)
        try sharing.share(resource, with: .cursor)
        try sharing.unshare(resource, from: .cursor)
        #expect(try String(contentsOf: home.appending(path: ".cursor/agents/reviewer.md"), encoding: .utf8).hasSuffix("B"))
    }

    @Test func linksClaudeToAProjectsAgentsFile() throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let agents = home.appending(path: "app/AGENTS.md")
        try write("# App\n", to: agents)
        let resource = try #require(MarkdownResourceParser.resource(at: agents, kind: .instructions, agent: .shared, scope: .project("app")))

        let sharing = InstructionSharing(home: home)
        #expect(sharing.state(of: resource, for: .shared) == .original)
        #expect(sharing.state(of: resource, for: .claudeCode) == .absent)
        try sharing.share(resource, with: .claudeCode)

        let claude = home.appending(path: "app/CLAUDE.md")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: claude.path(percentEncoded: false)) == "AGENTS.md")
        #expect(try String(contentsOf: claude, encoding: .utf8) == "# App\n")
    }

    @Test func convertsMCPServersBetweenFormats() throws {
        let config = MCPServerConfig.fromJSON([
            "command": "npx",
            "args": ["-y", "server-github"],
            "env": ["GITHUB_TOKEN": "abc"],
        ])
        #expect(config.codexTOML(name: "github") == """
        [mcp_servers.github]
        command = "npx"
        args = ["-y", "server-github"]

        [mcp_servers.github.env]
        GITHUB_TOKEN = "abc"

        """)
        #expect(config.claudeCommand(name: "github")?.hasPrefix("claude mcp add-json github '{") == true)

        let back = try #require(MCPServerConfig.fromTOML(config.codexTOML(name: "github"), name: "github"))
        #expect(back == config)

        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let cursor = home.appending(path: ".cursor/mcp.json")
        try write(#"{"mcpServers": {"figma": {"url": "https://x"}}, "other": 1}"#, to: cursor)
        try config.add(named: "github", toJSONFile: cursor)
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: cursor)) as? [String: Any]
        #expect((root?["mcpServers"] as? [String: Any])?.keys.sorted() == ["figma", "github"])
        #expect(root?["other"] as? Int == 1)
        #expect(throws: MCPServerConfig.WriteError.self) { try config.add(named: "github", toJSONFile: cursor) }
    }

    @Test func findsPlainTextKeysOnly() {
        let profile = """
        export OPENAI_API_KEY="sk-proj-abcdefghijklmnop"
        export GITHUB_TOKEN=ghp_1234567890abcdef1234 # personal
        export PATH="$HOME/bin:$PATH"
        export ANTHROPIC_API_KEY="$(security find-generic-password -w)"
        # export OLD_TOKEN=abc
        export EDITOR=vim
        """
        let findings = PlaintextSecretFinder.findings(inText: profile, file: URL(filePath: "/tmp/.zshenv"))
        #expect(findings.map(\.name) == ["OPENAI_API_KEY", "GITHUB_TOKEN"])
        #expect(findings[1].value == "ghp_1234567890abcdef1234")
        #expect(findings.map(\.line) == [0, 1])
        #expect(PlaintextFindingsView.masked("sk-proj-abcdefghijklmnop") == "sk-…mnop")
    }

    @Test func addsASkillToAProject() async throws {
        let home = try makeHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let skill = home.appending(path: ".agents/skills/review")
        try write("---\nname: review\n---\n", to: skill.appending(path: "SKILL.md"))
        let project = home.appending(path: "Developer/app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let installer = SkillInstaller(home: home)
        let placed = try await installer.addToProject(skill, name: "review", project: project, targets: [.claude, .cursor])
        #expect(FileManager.default.fileExists(atPath: placed.appending(path: "SKILL.md").path(percentEncoded: false)))
        let link = project.appending(path: ".claude/skills/review")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path(percentEncoded: false)) == "../../.agents/skills/review")
        #expect(FileManager.default.fileExists(atPath: link.appending(path: "SKILL.md").path(percentEncoded: false)))
    }
}
