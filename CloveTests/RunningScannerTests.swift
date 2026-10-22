import Foundation
import Testing
@testable import Clove

struct RunningScannerTests {
    /// Shaped like a real Mac: Claude's app running a Claude Code session,
    /// Cursor's MCP host with npx and gk servers, a dev server, and noise.
    private let ps = """
      750     1 07:25:16 101312 /Applications/Cursor.app/Contents/MacOS/Cursor
     1442   750 07:25:16 101312 Cursor Helper: mcp-process
    37409  1442 06:46:10  24192 npm exec shadcn@latest mcp
    37434 37409 06:46:09  30880 node /Users/me/.npm/_npx/d66c/node_modules/.bin/shadcn mcp
    37446  1442 06:46:08   4496 /Users/me/Library/Application Support/GitKrakenCLI/gk mcp --host=cursor
    37447 37446 06:46:08  23616 /Users/me/Library/Application Support/GitKrakenCLI/gk mcp --host=cursor
    75173     1 04:24:15 406768 /Applications/Claude.app/Contents/MacOS/Claude
    86354 75173 04:12:00 592592 /Users/me/Library/Application Support/Claude/claude-code/2.1.308/claude.app/Contents/MacOS/claude --output-format stream-json
    90000 86354 01:00:00   2000 /bin/zsh -c npm run dev
    90001 90000 01:00:00  80000 node /Users/me/Developer/app/node_modules/.bin/next dev
      780     1 1-02:00:00  9000 /System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter
     1805   750 07:25:11  18320 /Applications/Cursor.app/Contents/Resources/app/resources/helpers/node /Applications/Cursor.app/x.js
     2497     1 03:00:00  40000 node server.js
    """

    @Test func sortsProcessesIntoAgentsServersAndDevServers() {
        let comm = """
        86354 /Users/me/Library/Application Support/Claude/claude-code/2.1.308/claude.app/Contents/MacOS/claude
        37446 /Users/me/Library/Application Support/GitKrakenCLI/gk
        37447 /Users/me/Library/Application Support/GitKrakenCLI/gk
        """
        let table = ProcessTable.parse(ps, executables: comm)
        let ports: [Int32: [Int]] = [90001: [3000], 780: [5000], 1805: [49314], 2497: [7265]]
        let found = RunningScanner.classify(
            table: table,
            ports: ports,
            known: [.init(name: "GitKraken", signature: "gk mcp")]
        )

        let agents = found.filter { $0.kind == .agent }
        #expect(agents.map(\.name) == ["Claude Code"])
        #expect(agents.first?.startedBy == "Claude")

        let servers = found.filter { $0.kind == .mcpServer }
        #expect(Set(servers.map(\.name)) == ["shadcn", "GitKraken"])
        #expect(servers.allSatisfy { $0.startedBy == "Cursor" })
        // npm exec and its node child are one server, with their memory combined.
        #expect(servers.first { $0.name == "shadcn" }?.memoryBytes == Int64(24192 + 30880) * 1024)

        let dev = found.filter { $0.kind == .devServer }
        #expect(Set(dev.map(\.pid)) == [90001, 2497])
        #expect(dev.first { $0.pid == 90001 }?.ports == [3000])
        #expect(dev.first { $0.pid == 90001 }?.startedBy == "Claude Code")
    }

    @Test func readsPSElapsedTimes() {
        #expect(ProcessTable.elapsed("05:09") == 309)
        #expect(ProcessTable.elapsed("02:05:09") == 7509)
        #expect(ProcessTable.elapsed("1-00:00:01") == 86_401)
    }

    @Test func readsListeningPorts() {
        let lsof = "p123\nn127.0.0.1:3000\nn[::1]:3000\np456\nn*:8080\n"
        #expect(RunningScanner.listeningPorts(lsof) == [123: [3000], 456: [8080]])
        #expect(RunningScanner.packageName("@playwright/mcp@latest") == "@playwright/mcp")
        #expect(RunningScanner.packageName("shadcn@latest") == "shadcn")
    }
}
