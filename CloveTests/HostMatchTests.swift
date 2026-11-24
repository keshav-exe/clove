import Foundation
import Testing
@testable import Clove

struct HostMatchTests {
    private static func entry(_ pid: Int32, _ parent: Int32, _ executable: String, _ args: String? = nil, elapsed: TimeInterval = 60) -> ProcessTable.Entry {
        ProcessTable.Entry(pid: pid, parent: parent, elapsed: elapsed, residentKB: 1000, args: args ?? executable, executable: executable)
    }

    private let id = "6a2f7a4c-096c-4b58-9de9-efc8347ff25a"

    /// Two apps each running Claude in the same project: T3 Code resuming
    /// this conversation, and the Claude app's agent, started more recently.
    private var sample: ProcessSample {
        ProcessSample(table: ProcessTable(entries: [
            Self.entry(900, 1, "/Applications/T3 Code.app/Contents/MacOS/T3 Code"),
            Self.entry(901, 900, "/opt/homebrew/bin/claude", "claude --resume \(id) --output-format stream-json", elapsed: 120),
            Self.entry(700, 1, "/Applications/Claude.app/Contents/MacOS/Claude"),
            Self.entry(701, 700, "/Users/me/Library/Application Support/Claude/claude-code/claude.app/Contents/MacOS/claude", "claude --output-format stream-json", elapsed: 5),
            // A tool whose path happens to hold the ID and the word "claude".
            Self.entry(600, 1, "/tmp/claude-501/\(id)/Build/Tool.app/Contents/MacOS/Tool", elapsed: 1),
        ]), ports: [:], cpuTime: [:], takenAt: 0)
    }

    private let apps: [String: RunningAppInfo] = [
        "/Applications/T3 Code.app": .init(name: "T3 Code", bundleID: "com.t3tools.t3code"),
        "/Applications/Claude.app": .init(name: "Claude", bundleID: "com.anthropic.claudefordesktop"),
    ]

    @Test func theProcessNamingTheConversationWins() {
        let host = AgentHostFinder.find(folder: "/Users/me/marketplace", agent: .claude, sample: sample, apps: apps, workingFolder: { _ in "/Users/me/marketplace" }, conversationID: id)
        #expect(host?.name == "T3 Code")
        // Without the ID, the newest agent in the folder is the guess.
        let guess = AgentHostFinder.find(folder: "/Users/me/marketplace", agent: .claude, sample: sample, apps: apps, workingFolder: { _ in "/Users/me/marketplace" })
        #expect(guess?.name == "Claude")
    }

    @Test func readsTheConversationIDFromItsTranscript() {
        #expect(AgentHostFinder.conversationID(fromTranscript: "/Users/me/.claude/projects/-x/\(id).jsonl") == id)
        #expect(AgentHostFinder.conversationID(fromTranscript: "/Users/me/.codex/sessions/2026/11/24/rollout-2026-11-24T10-00-00-\(id).jsonl") == id)
        #expect(AgentHostFinder.conversationID(fromTranscript: "/tmp/notes.jsonl") == nil)
    }
}
