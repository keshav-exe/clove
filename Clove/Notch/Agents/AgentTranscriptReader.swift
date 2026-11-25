import Foundation

/// Reads the end of an agent's transcript into an `AgentSession`. Only the
/// tail is read: the current turn is what the notch shows, and transcripts
/// run to many megabytes.
enum AgentTranscriptReader {
    /// How much of the file's end to read. A turn's steps fit well inside this.
    static let tailBytes = 384 * 1024
    /// Steps kept per turn: the island shows the last few.
    static let maxSteps = 6

    static func read(_ file: URL, agent: AgentSession.Agent) -> AgentSession? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > UInt64(tailBytes) ? size - UInt64(tailBytes) : 0
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        // The first line of a partial read is cut in half.
        if start > 0, !lines.isEmpty { lines.removeFirst() }
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now
        switch agent {
        case .claude: return claude(lines: lines, id: file.path, modified: modified)
        case .codex: return codex(lines: lines, id: file.path, modified: modified)
        }
    }

    // MARK: - Claude Code

    /// `~/.claude/projects/<folder>/<session>.jsonl`: one JSON object per line,
    /// `assistant` entries carrying `tool_use` blocks and `user` entries
    /// carrying their `tool_result`s or your next prompt.
    static func claude(lines: [Substring], id: String, modified: Date) -> AgentSession? {
        var session = AgentSession(id: id, agent: .claude, folder: nil, title: nil, state: .working, steps: [], change: nil, summary: nil, updatedAt: modified)
        var sawTurn = false

        for line in lines {
            guard let entry = object(line) else { continue }
            let type = entry["type"] as? String
            if let title = entry["customTitle"] as? String ?? entry["agentName"] as? String, !title.isEmpty {
                session.title = title
            }
            // Subagents write into the same file; their steps aren't the session's.
            if entry["isSidechain"] as? Bool == true { continue }
            if let cwd = entry["cwd"] as? String, !cwd.isEmpty {
                session.folder = URL(filePath: cwd, directoryHint: .isDirectory)
            }
            guard let message = entry["message"] as? [String: Any] else { continue }

            if type == "user" {
                if entry["isMeta"] as? Bool == true { continue }
                if let prompt = message["content"] as? String {
                    if isInterruption(prompt) {
                        session.state = .interrupted
                    } else if let job = finishedJob(prompt) {
                        session.backgroundJobs.remove(job)
                        // The report wakes the agent up to read it.
                        session.awaitsBackground = false
                    } else if !isSystemText(prompt) {
                        startTurn(&session, entry: entry)
                        sawTurn = true
                    }
                    continue
                }
                guard let blocks = message["content"] as? [[String: Any]] else { continue }
                var startsTurn = false
                for block in blocks {
                    switch block["type"] as? String {
                    case "tool_result":
                        if let toolID = block["tool_use_id"] as? String {
                            markDone(toolID, in: &session)
                        }
                    case "text":
                        let text = block["text"] as? String ?? ""
                        if isInterruption(text) {
                            session.state = .interrupted
                        } else if let job = finishedJob(text) {
                            session.backgroundJobs.remove(job)
                            session.awaitsBackground = false
                        } else if !isSystemText(text) {
                            startsTurn = true
                        }
                    default:
                        break
                    }
                }
                if startsTurn {
                    startTurn(&session, entry: entry)
                    sawTurn = true
                }
            } else if type == "assistant" {
                sawTurn = true
                // A request that failed for good (a usage limit, an outage) ends the task.
                if entry["isApiErrorMessage"] as? Bool == true {
                    let text = (message["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.first
                    session.failure = text.flatMap(firstLine) ?? "The request failed."
                    session.state = .finished
                    session.asksQuestion = false
                    continue
                }
                session.state = .working
                session.awaitsBackground = false
                for block in message["content"] as? [[String: Any]] ?? [] {
                    switch block["type"] as? String {
                    case "tool_use":
                        let name = block["name"] as? String ?? "Tool"
                        let input = block["input"] as? [String: Any] ?? [:]
                        let id = block["id"] as? String ?? UUID().uuidString
                        addStep(id: id, tool: name, input: input, to: &session)
                        if input["run_in_background"] as? Bool == true { session.backgroundJobs.insert(id) }
                    case "text":
                        if let text = block["text"] as? String, let line = firstLine(text) {
                            session.summary = line
                            session.asksQuestion = lastLine(text)?.hasSuffix("?") == true
                        }
                    default:
                        break
                    }
                }
                // The turn ending isn't the task ending while background work is still out.
                if message["stop_reason"] as? String == "end_turn", session.currentStep == nil {
                    session.state = session.backgroundJobs.isEmpty ? .finished : .working
                    session.awaitsBackground = !session.backgroundJobs.isEmpty
                }
            }
        }
        return sawTurn ? session : nil
    }

    private static func addStep(id: String, tool: String, input: [String: Any], to session: inout AgentSession) {
        let (verb, target) = describe(tool: tool, input: input)
        session.steps.append(AgentSession.Step(id: id, verb: verb, target: target, isDone: false))
        if session.steps.count > maxSteps { session.steps.removeFirst(session.steps.count - maxSteps) }

        // The file it's changing, with a running count of lines this turn.
        let path = input["file_path"] as? String ?? input["notebook_path"] as? String
        guard let path, ["Edit", "MultiEdit", "Write", "NotebookEdit"].contains(tool) else { return }
        var counts: (added: Int, removed: Int) = (0, 0)
        if tool == "Write" {
            counts.added = lineCount(input["content"] as? String ?? "")
        } else if let edits = input["edits"] as? [[String: Any]] {
            for edit in edits {
                let delta = diffCounts(old: edit["old_string"] as? String ?? "", new: edit["new_string"] as? String ?? "")
                counts.added += delta.added
                counts.removed += delta.removed
            }
        } else {
            counts = diffCounts(old: input["old_string"] as? String ?? "", new: input["new_string"] as? String ?? input["new_source"] as? String ?? "")
        }
        recordChange(file: path, counts: counts, in: &session)
    }

    /// Plain words for each tool, so a step reads like "Edit Hero.swift".
    static func describe(tool: String, input: [String: Any]) -> (String, String?) {
        let file = (input["file_path"] as? String ?? input["notebook_path"] as? String).map { URL(filePath: $0).lastPathComponent }
        switch tool {
        case "Read": return ("Read", file)
        case "Edit", "MultiEdit", "NotebookEdit": return ("Edit", file)
        case "Write": return ("Write", file)
        case "Bash":
            if let description = input["description"] as? String, !description.isEmpty { return (description, nil) }
            return ("Run", (input["command"] as? String).flatMap(commandName))
        case "Grep", "Glob": return ("Search", input["pattern"] as? String)
        case "WebSearch": return ("Search the web", input["query"] as? String)
        case "WebFetch": return ("Read", (input["url"] as? String).flatMap { URL(string: $0)?.host() })
        case "Task", "Agent": return ("Hand off", input["description"] as? String)
        case "TodoWrite": return ("Update the plan", nil)
        default:
            // MCP tools arrive as mcp__server__tool_name: say "Tool name".
            let name = (tool.components(separatedBy: "__").last ?? tool).replacingOccurrences(of: "_", with: " ")
            return (name.prefix(1).uppercased() + name.dropFirst(), nil)
        }
    }

    // MARK: - Codex

    /// `~/.codex/sessions/<y>/<m>/<d>/rollout-*.jsonl`: `event_msg` entries
    /// mark turns starting and ending, `response_item` entries carry tool calls.
    static func codex(lines: [Substring], id: String, modified: Date) -> AgentSession? {
        var session = AgentSession(id: id, agent: .codex, folder: nil, title: nil, state: .working, steps: [], change: nil, summary: nil, updatedAt: modified)
        var sawTurn = false

        for line in lines {
            guard let entry = object(line), let payload = entry["payload"] as? [String: Any] else { continue }
            let kind = payload["type"] as? String
            switch entry["type"] as? String {
            case "session_meta", "turn_context":
                if let cwd = payload["cwd"] as? String, !cwd.isEmpty {
                    session.folder = URL(filePath: cwd, directoryHint: .isDirectory)
                }
            case "event_msg":
                switch kind {
                case "task_started", "user_message":
                    if !sawTurn || session.state != .working { startTurn(&session, entry: entry) }
                    sawTurn = true
                case "task_complete":
                    sawTurn = true
                    session.state = .finished
                    for index in session.steps.indices { session.steps[index].isDone = true }
                    if let text = payload["last_agent_message"] as? String, let line = firstLine(text) {
                        session.summary = line
                        session.asksQuestion = lastLine(text)?.hasSuffix("?") == true
                    }
                case "turn_aborted":
                    session.state = .interrupted
                default:
                    break
                }
            case "response_item":
                switch kind {
                case "function_call", "local_shell_call":
                    sawTurn = true
                    session.state = .working
                    let arguments = (payload["arguments"] as? String).flatMap { object(Substring($0)) } ?? [:]
                    let command = arguments["command"] as? [String] ?? (arguments["cmd"] as? String).map { [$0] } ?? []
                    let shell = command.last.flatMap(commandName)
                    session.steps.append(AgentSession.Step(id: payload["call_id"] as? String ?? UUID().uuidString, verb: "Run", target: shell, isDone: false))
                case "custom_tool_call":
                    sawTurn = true
                    session.state = .working
                    let callID = payload["call_id"] as? String ?? UUID().uuidString
                    if payload["name"] as? String == "apply_patch", let patch = payload["input"] as? String {
                        let files = patchFiles(patch)
                        session.steps.append(AgentSession.Step(id: callID, verb: "Edit", target: files.first.map { URL(filePath: $0.path).lastPathComponent }, isDone: false))
                        for file in files {
                            recordChange(file: file.path, counts: (file.added, file.removed), in: &session)
                        }
                    } else {
                        session.steps.append(AgentSession.Step(id: callID, verb: (payload["name"] as? String) ?? "Tool", target: nil, isDone: false))
                    }
                case "function_call_output", "custom_tool_call_output":
                    if let callID = payload["call_id"] as? String { markDone(callID, in: &session) }
                case "message":
                    guard payload["role"] as? String == "assistant" else { break }
                    for block in payload["content"] as? [[String: Any]] ?? [] {
                        if let text = block["text"] as? String, let line = firstLine(text) { session.summary = line }
                    }
                default:
                    break
                }
                if session.steps.count > maxSteps { session.steps.removeFirst(session.steps.count - maxSteps) }
            default:
                break
            }
        }
        return sawTurn ? session : nil
    }

    /// The files an `apply_patch` touches, with the lines it adds and removes in each.
    static func patchFiles(_ patch: String) -> [(path: String, added: Int, removed: Int)] {
        var files: [(path: String, added: Int, removed: Int)] = []
        for line in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            for marker in ["*** Update File: ", "*** Add File: ", "*** Delete File: "] where line.hasPrefix(marker) {
                files.append((String(line.dropFirst(marker.count)), 0, 0))
            }
            guard !files.isEmpty, !line.hasPrefix("***") else { continue }
            if line.hasPrefix("+") { files[files.count - 1].added += 1 }
            else if line.hasPrefix("-") { files[files.count - 1].removed += 1 }
        }
        return files
    }

    // MARK: - Shared

    private static func startTurn(_ session: inout AgentSession, entry: [String: Any]) {
        session.state = .working
        session.steps = []
        session.change = nil
        session.summary = nil
        session.failure = nil
        session.asksQuestion = false
        session.backgroundJobs = []
        session.awaitsBackground = false
        let timestamp = entry["timestamp"] as? String
        session.promptID = entry["uuid"] as? String ?? timestamp
        session.startedAt = timestamp.flatMap { try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse($0) }
    }

    /// The tool call a `<task-notification>` reports on: a background command
    /// or subagent the agent started, now done.
    static func finishedJob(_ text: String) -> String? {
        guard text.hasPrefix("<task-notification>"),
              let start = text.range(of: "<tool-use-id>"),
              let end = text.range(of: "</tool-use-id>", range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lastLine(_ text: String) -> String? {
        text.split(separator: "\n").lazy.map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
    }

    private static func markDone(_ id: String, in session: inout AgentSession) {
        if let index = session.steps.firstIndex(where: { $0.id == id }) {
            session.steps[index].isDone = true
        }
    }

    private static func recordChange(file: String, counts: (added: Int, removed: Int), in session: inout AgentSession) {
        let name = URL(filePath: file).lastPathComponent
        if session.change?.name == name {
            session.change?.added += counts.added
            session.change?.removed += counts.removed
        } else {
            session.change = AgentSession.FileChange(name: name, added: counts.added, removed: counts.removed)
        }
    }

    /// Lines that differ once the shared start and end are set aside, the way a diff counts them.
    static func diffCounts(old: String, new: String) -> (added: Int, removed: Int) {
        var before = old.split(separator: "\n", omittingEmptySubsequences: false)[...]
        var after = new.split(separator: "\n", omittingEmptySubsequences: false)[...]
        if old.isEmpty { before = [] }
        if new.isEmpty { after = [] }
        while let first = before.first, first == after.first {
            before.removeFirst()
            after.removeFirst()
        }
        while let last = before.last, last == after.last {
            before.removeLast()
            after.removeLast()
        }
        return (after.count, before.count)
    }

    private static func lineCount(_ text: String) -> Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    /// `cd app && npm run dev` reads best as its program: "npm".
    static func commandName(_ command: String) -> String? {
        let last = command.components(separatedBy: "&&").last ?? command
        let words = last.split(separator: " ").map(String.init).filter { !$0.contains("=") }
        guard let first = words.first else { return nil }
        let program = URL(filePath: first).lastPathComponent
        if ["npm", "pnpm", "yarn", "bun", "swift", "cargo", "go", "git", "xcodebuild", "make"].contains(program), words.count > 1 {
            return "\(program) \(words[1])"
        }
        return program
    }

    private static func firstLine(_ text: String) -> String? {
        let line = text.split(separator: "\n").lazy.map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
        guard let line else { return nil }
        let plain = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        return plain.count > 140 ? String(plain.prefix(139)) + "…" : plain
    }

    private static func isInterruption(_ text: String) -> Bool {
        text.hasPrefix("[Request interrupted by user")
    }

    /// Text the harness writes into a user entry that isn't you typing.
    private static func isSystemText(_ text: String) -> Bool {
        text.hasPrefix("<") || text.hasPrefix("Caveat:")
    }

    private static func object(_ line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
