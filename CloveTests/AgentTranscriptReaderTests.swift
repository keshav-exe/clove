import Foundation
import Testing
@testable import Clove

struct AgentTranscriptReaderTests {
    private func lines(_ entries: [String]) -> [Substring] {
        entries.map { Substring($0) }
    }

    private let prompt = #"{"type":"user","cwd":"/Users/me/Developer/app","message":{"role":"user","content":"Fix the hero"}}"#

    @Test func claudeTurnInProgress() throws {
        let session = try #require(AgentTranscriptReader.claude(lines: lines([
            #"{"type":"custom-title","customTitle":"Hero fix"}"#,
            prompt,
            #"{"type":"assistant","cwd":"/Users/me/Developer/app","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"a","name":"Read","input":{"file_path":"/Users/me/Developer/app/Notes.md"}}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"ok"}]}}"#,
            #"{"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"b","name":"Edit","input":{"file_path":"/Users/me/Developer/app/Hero.swift","old_string":"a\nb\nc","new_string":"a\nB\nB2\nc"}}]}}"#,
        ]), id: "t", modified: .now))

        #expect(session.state == .working)
        #expect(session.title == "Hero fix")
        #expect(session.project == "app")
        #expect(session.steps.map(\.verb) == ["Read", "Edit"])
        #expect(session.steps.map(\.isDone) == [true, false])
        #expect(session.statusText == "Edit Hero.swift")
        #expect(session.change == AgentSession.FileChange(name: "Hero.swift", added: 2, removed: 1))
    }

    @Test func claudeFinishedTurn() throws {
        let session = try #require(AgentTranscriptReader.claude(lines: lines([
            prompt,
            #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"**Done.** The hero is fixed.\nMore detail"}]}}"#,
        ]), id: "t", modified: .now))

        #expect(session.state == .finished)
        #expect(session.summary == "Done. The hero is fixed.")
    }

    @Test func claudeNewPromptStartsAFreshTurn() throws {
        let session = try #require(AgentTranscriptReader.claude(lines: lines([
            prompt,
            #"{"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"tool_use","id":"a","name":"Bash","input":{"command":"cd app && npm run dev"}}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a"}]}}"#,
            #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Running."}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"text","text":"Now the footer"}]}}"#,
        ]), id: "t", modified: .now))

        #expect(session.state == .working)
        #expect(session.steps.isEmpty)
        #expect(session.statusText == "Thinking")
    }

    @Test func claudeIgnoresSidechainsAndInterruptions() throws {
        let session = try #require(AgentTranscriptReader.claude(lines: lines([
            prompt,
            #"{"type":"assistant","isSidechain":true,"message":{"content":[{"type":"tool_use","id":"s","name":"Read","input":{}}]}}"#,
            #"{"type":"user","message":{"content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#,
        ]), id: "t", modified: .now))

        #expect(session.steps.isEmpty)
        #expect(session.state == .interrupted)
    }

    @Test func codexTurn() throws {
        let working = try #require(AgentTranscriptReader.codex(lines: lines([
            #"{"type":"session_meta","payload":{"cwd":"/Users/me/Developer/api"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call","name":"shell","call_id":"c1","arguments":"{\"command\":[\"bash\",\"-lc\",\"swift build\"]}"}}"#,
            #"{"type":"response_item","payload":{"type":"function_call_output","call_id":"c1"}}"#,
            #"{"type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","call_id":"c2","input":"*** Begin Patch\n*** Update File: Sources/App.swift\n-old\n+new\n+more\n*** End Patch"}}"#,
        ]), id: "t", modified: .now))

        #expect(working.state == .working)
        #expect(working.project == "api")
        #expect(working.steps.map(\.verb) == ["Run", "Edit"])
        #expect(working.steps.first?.target == "swift build")
        #expect(working.change == AgentSession.FileChange(name: "App.swift", added: 2, removed: 1))

        let finished = try #require(AgentTranscriptReader.codex(lines: lines([
            #"{"type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"type":"event_msg","payload":{"type":"task_complete","last_agent_message":"All tests pass."}}"#,
        ]), id: "t", modified: .now))
        #expect(finished.state == .finished)
        #expect(finished.summary == "All tests pass.")
    }

    @Test func noTurnMeansNoSession() {
        #expect(AgentTranscriptReader.claude(lines: lines([#"{"type":"custom-title","customTitle":"x"}"#]), id: "t", modified: .now) == nil)
    }

    @Test func diffCountsSkipSharedLines() {
        #expect(AgentTranscriptReader.diffCounts(old: "a\nb\nc", new: "a\nx\nc") == (1, 1))
        #expect(AgentTranscriptReader.diffCounts(old: "", new: "a\nb") == (2, 0))
    }

    @Test func commandNames() {
        #expect(AgentTranscriptReader.commandName("cd app && npm run dev") == "npm run")
        #expect(AgentTranscriptReader.commandName("/usr/bin/git status") == "git status")
        #expect(AgentTranscriptReader.commandName("NODE_ENV=test node x.js") == "node")
    }

    @Test func freshness() {
        var session = AgentSession(id: "t", agent: .claude, folder: nil, title: nil, state: .finished, steps: [], change: nil, summary: nil, updatedAt: .now.addingTimeInterval(-30 * 60))
        #expect(!AgentActivityStore.isFresh(session))
        session.updatedAt = .now.addingTimeInterval(-60)
        #expect(AgentActivityStore.isFresh(session))
    }
}

extension AgentTranscriptReaderTests {
    @Test func mcpToolsReadAsWords() {
        #expect(AgentTranscriptReader.describe(tool: "mcp__computer-use__request_access", input: [:]).0 == "Request access")
    }
}
