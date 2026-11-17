import Darwin
import Foundation
import Testing
@testable import Clove

struct ActivityTests {
    private static func entry(_ pid: Int32, _ parent: Int32, _ executable: String, _ args: String? = nil, kb: Int64 = 1000) -> ProcessTable.Entry {
        ProcessTable.Entry(pid: pid, parent: parent, elapsed: 60, residentKB: kb, args: args ?? executable, executable: executable)
    }

    /// Cursor and a helper; Claude Code in a Ghostty tab with an MCP server
    /// under it; T3 Code driving Claude through the Agent SDK.
    private let table = ProcessTable(entries: [
        entry(750, 1, "/Applications/Cursor.app/Contents/MacOS/Cursor"),
        entry(751, 750, "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Renderer).app/Contents/MacOS/Cursor Helper (Renderer)"),
        entry(800, 1, "/Applications/Ghostty.app/Contents/MacOS/ghostty"),
        entry(801, 800, "/usr/bin/login", "login -fp me"),
        entry(802, 801, "/bin/zsh", "-zsh"),
        entry(803, 802, "/Users/me/.local/bin/claude", "claude --continue"),
        entry(804, 803, "/opt/homebrew/bin/node", "node /Users/me/.npm/_npx/x/node_modules/.bin/shadcn mcp"),
        entry(900, 1, "/Applications/T3 Code.app/Contents/MacOS/T3 Code"),
        entry(901, 900, "/opt/homebrew/bin/node", "node /x/node_modules/@anthropic-ai/claude-agent-sdk/cli.js"),
    ])

    private let apps: [String: RunningAppInfo] = [
        "/Applications/Cursor.app": .init(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92"),
        "/Applications/Ghostty.app": .init(name: "Ghostty", bundleID: "com.mitchellh.ghostty"),
        "/Applications/T3 Code.app": .init(name: "T3 Code", bundleID: "com.t3tools.t3code"),
    ]

    @Test func findsTheOutermostApp() {
        #expect(ActivityReport.outerBundle("/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/x") == "/Applications/Cursor.app")
        #expect(ActivityReport.outerBundle("/Applications/Xcode.app") == "/Applications/Xcode.app")
        #expect(ActivityReport.outerBundle("/opt/homebrew/bin/node") == nil)
        #expect(ActivityReport.outerBundle("node server.js") == nil)
    }

    @Test func groupsByAppOrCommandWithProcessorShare() {
        let previous = ProcessSample(table: table, ports: [:], cpuTime: [751: 0, 803: 0, 804: 0], takenAt: 0)
        let current = ProcessSample(table: table, ports: [:], cpuTime: [751: 2_000_000_000, 803: 500_000_000, 804: 100_000_000], takenAt: 1_000_000_000)
        let groups = ActivityReport.build(current: current, previous: previous, apps: apps, ownPID: 0) { $0 == 803 ? "/Users/me/app" : nil }

        #expect(groups.map(\.name).prefix(2) == ["Cursor", "Claude Code"])
        let cursor = groups[0]
        #expect(cursor.processCount == 2)
        #expect(abs(cursor.cpu - 200) < 0.01)

        // Claude in a terminal is Claude Code, its MCP server counted with it.
        let claude = groups[1]
        #expect(claude.kind == .command)
        #expect(claude.rootPID == 803)
        #expect(Set(claude.members.map(\.pid)) == [803, 804])
        #expect(abs(claude.cpu - 60) < 0.01)
        #expect(claude.folder == "/Users/me/app")

        // The terminal keeps its own shell, not the commands run in it.
        let ghostty = groups.first { $0.name == "Ghostty" }
        #expect(Set(ghostty?.members.map(\.pid) ?? []) == [800, 801, 802])

        // An app driving an agent owns it.
        let t3 = groups.first { $0.name == "T3 Code" }
        #expect(Set(t3?.members.map(\.pid) ?? []) == [900, 901])
    }

    @Test func readsNoProcessorUseFromOneLook() {
        let current = ProcessSample(table: table, ports: [:], cpuTime: [751: 9], takenAt: 5)
        let groups = ActivityReport.build(current: current, previous: nil, apps: apps, ownPID: 0)
        #expect(groups.allSatisfy { $0.cpu == 0 })
    }

    @Test func findsTheAppAnAgentRunsIn() {
        let sample = ProcessSample(table: table, ports: [:], cpuTime: [:], takenAt: 0)
        let folders: [Int32: String] = [901: "/Users/me/app", 803: "/Users/me/other"]

        let t3 = AgentHostFinder.find(folder: "/Users/me/app", agent: .claude, sample: sample, apps: apps) { folders[$0] }
        #expect(t3?.name == "T3 Code")
        #expect(t3?.agentPID == 901)

        let ghostty = AgentHostFinder.find(folder: "/Users/me/other", agent: .claude, sample: sample, apps: apps) { folders[$0] }
        #expect(ghostty?.name == "Ghostty")

        #expect(AgentHostFinder.find(folder: "/Users/me/app", agent: .codex, sample: sample, apps: apps) { folders[$0] } == nil)
    }

    /// Against this Mac's real processes: finds this test run, its command
    /// line, and a port it listens on, quickly.
    @Test func readsLiveProcesses() async throws {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        try #require(socket >= 0)
        defer { close(socket) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = 0
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        try #require(bound == 0)
        try #require(listen(socket, 1) == 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &address) {
            _ = $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socket, $0, &length) }
        }
        let port = Int(UInt16(bigEndian: address.sin_port))

        let monitor = ProcessMonitor()
        let start = ContinuousClock.now
        let sample = await monitor.sample()
        let first = ContinuousClock.now - start
        let again = ContinuousClock.now
        _ = await monitor.sample()
        let second = ContinuousClock.now - again
        print("Process look: first \(first), then \(second), \(sample.table.entries.count) processes")

        let me = try #require(sample.table.entries[getpid()])
        #expect(!me.args.isEmpty)
        #expect(me.residentKB > 0)
        #expect((sample.cpuTime[getpid()] ?? 0) > 0)
        #expect(sample.ports[getpid()]?.contains(port) == true)
        #expect(ProcessMonitor.workingFolder(of: getpid()) != nil || FileManager.default.currentDirectoryPath == "/")
        #expect(second < .milliseconds(250))
    }
}
