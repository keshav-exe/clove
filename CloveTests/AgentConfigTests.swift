import Foundation
import Testing
@testable import Clove

struct AgentConfigTests {
    private let file = URL(filePath: "/tmp/config.json")

    @Test func readsMCPServersWithoutSecrets() {
        let json = #"""
        {"mcpServers": {
          "github": {"command": "npx", "args": ["-y", "server-github", "--token", "ghp_abcdefghijklmnopqrstuvwxyz0123456789"], "env": {"GITHUB_TOKEN": "ghp_secretvalue1234567890"}},
          "figma": {"url": "https://mcp.figma.com/mcp?key=sk-live-123456789", "headers": {"Authorization": "Bearer abc"}},
          "old": {"command": "node", "disabled": true}
        }}
        """#
        let servers = MCPConfigParser.servers(inJSON: Data(json.utf8), file: file, agent: .cursor, scope: .global)
        #expect(servers.map(\.name) == ["figma", "github", "old"])

        let everything = servers.flatMap(\.details).map(\.value).joined(separator: " ") + servers.map(\.summary).joined()
        #expect(!everything.contains("ghp_"))
        #expect(!everything.contains("sk-live"))
        #expect(!everything.contains("Bearer abc"))
        #expect(everything.contains("GITHUB_TOKEN"))
        #expect(servers[2].summary == "Turned off")
    }

    @Test func readsCodexTOMLServers() {
        let toml = """
        notify = ["say", "done"]

        [mcp_servers.node_repl]
        command = "node"
        args = ["repl.js"]

        [mcp_servers.node_repl.env]
        API_KEY = "secret"

        [mcp_servers."Figma — Station"]
        url = "https://example.com/mcp"

        [features]
        web = true
        """
        let servers = MCPConfigParser.servers(inTOML: toml, file: file, scope: .global)
        #expect(servers.map(\.name) == ["Figma — Station", "node_repl"])
        let repl = servers[1].details.map(\.value).joined(separator: " ")
        #expect(repl.contains("node repl.js"))
        #expect(repl.contains("API_KEY"))
        #expect(!repl.contains("secret"))

        let hooks = HookConfigParser.codexNotify(inTOML: toml, file: file)
        #expect(hooks.first?.summary == "say done")
    }

    @Test func readsClaudeHooksAndPermissions() {
        let json = #"""
        {"hooks": {"PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "/nonexistent/format.sh"}]}]},
         "permissions": {"allow": ["Bash(npm test:*)"], "deny": ["Read(.env)"]}}
        """#
        let hooks = HookConfigParser.claudeHooks(inJSON: Data(json.utf8), file: file, scope: .global)
        #expect(hooks.count == 1)
        #expect(hooks[0].name == "Post Tool Use · Edit|Write")
        #expect(hooks[0].problem != nil)

        let permissions = PermissionsParser.permissions(inJSON: Data(json.utf8), file: file, scope: .global)
        #expect(permissions.map(\.summary) == ["Allowed", "Blocked"])
    }

    @Test func readsCursorHooks() {
        let json = #"{"version": 1, "hooks": {"afterFileEdit": [{"command": "echo hi"}]}}"#
        let hooks = HookConfigParser.cursorHooks(inJSON: Data(json.utf8), file: file, scope: .project("app"))
        #expect(hooks.map(\.name) == ["After File Edit"])
        #expect(hooks[0].problem == nil)
    }

    @Test func readsHookProgramsWithSpaces() {
        #expect(HookConfigParser.firstWord(of: #""/Applications/My App.app/run" --fast"#) == "/Applications/My App.app/run")
        #expect(HookConfigParser.firstWord(of: "./format.sh --all") == "./format.sh")
        let folder = URL.temporaryDirectory.appending(path: "Clove Hook \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let program = folder.appending(path: "notify")
        FileManager.default.createFile(atPath: program.path(percentEncoded: false), contents: Data())

        let toml = "notify = [\"\(program.path(percentEncoded: false))\", \"done\"]"
        let hooks = HookConfigParser.codexNotify(inTOML: toml, file: file)
        #expect(hooks.count == 1)
        #expect(hooks.first?.problem == nil)
    }

    @Test func describesCursorRuleTriggers() {
        #expect(MarkdownResourceParser.ruleTrigger(["alwaysapply": "true"]) == "Always")
        #expect(MarkdownResourceParser.ruleTrigger(["globs": "*.swift"]) == "When matching files are open")
        #expect(MarkdownResourceParser.ruleTrigger(["description": "Use for tests"]) == "When the agent decides it's relevant")
        #expect(MarkdownResourceParser.ruleTrigger([:]) == "Only when mentioned")
    }

    @Test func masksCredentialsInCommandLines() {
        #expect(SecretRedactor.redact("run --api-key abc123") == "run --api-key ••••••")
        #expect(SecretRedactor.redact("run TOKEN=abc") == "run TOKEN=••••••")
        #expect(SecretRedactor.redact("npx -y @scope/server /Users/me/project") == "npx -y @scope/server /Users/me/project")
    }

    @Test func tracksSubagentsAndRealMCPCalls() {
        let transcript = #"""
        {"tools":[{"name":"mcp__listed__tool","description":"only listed"}]}
        {"type":"tool_use","id":"toolu_1","name":"mcp__Figma__get_design","input":{}}
        {"type":"tool_use","id":"toolu_2","name":"Task","input":{"subagent_type":"code-reviewer"}}
        """#
        let names = AgentUsageScanner.skillNames(in: Data(transcript.utf8))
        #expect(names.contains("mcp:figma"))
        #expect(!names.contains("mcp:listed"))
        #expect(names.contains("agent:code-reviewer"))
        #expect(AgentResource.normalizedServerName("Figma — Station") == "figma___station")
    }
}
