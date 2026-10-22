import Foundation

/// Hooks from Claude Code settings, Cursor's hooks.json, and Codex's `notify`.
enum HookConfigParser {
    /// Claude Code: `{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "…"}]}]}}`
    static func claudeHooks(inJSON data: Data, file: URL, scope: ResourceScope) -> [AgentResource] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let events = root["hooks"] as? [String: Any]
        else { return [] }

        var hooks: [AgentResource] = []
        for (event, value) in events {
            for (groupIndex, group) in ((value as? [[String: Any]]) ?? []).enumerated() {
                let matcher = group["matcher"] as? String
                for (index, hook) in ((group["hooks"] as? [[String: Any]]) ?? []).enumerated() {
                    guard let command = hook["command"] as? String else { continue }
                    hooks.append(resource(
                        event: event,
                        matcher: matcher,
                        command: command,
                        key: "\(event)#\(groupIndex)#\(index)",
                        file: file,
                        agent: .claudeCode,
                        scope: scope
                    ))
                }
            }
        }
        return hooks.sorted { $0.name < $1.name }
    }

    /// Cursor: `{"version": 1, "hooks": {"afterFileEdit": [{"command": "./hooks/format.sh"}]}}`
    static func cursorHooks(inJSON data: Data, file: URL, scope: ResourceScope) -> [AgentResource] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let events = root["hooks"] as? [String: Any]
        else { return [] }

        var hooks: [AgentResource] = []
        for (event, value) in events {
            for (index, hook) in ((value as? [[String: Any]]) ?? []).enumerated() {
                guard let command = hook["command"] as? String else { continue }
                hooks.append(resource(
                    event: event,
                    matcher: hook["matcher"] as? String,
                    command: command,
                    key: "\(event)#\(index)",
                    file: file,
                    agent: .cursor,
                    scope: scope
                ))
            }
        }
        return hooks.sorted { $0.name < $1.name }
    }

    /// Codex runs `notify = ["program", "arg"]` when a turn finishes.
    static func codexNotify(inTOML text: String, file: URL) -> [AgentResource] {
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("notify"), let equals = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            var parts = TOMLTables.array(value)
            if parts.isEmpty, value == "[" {
                parts = multilineArray(after: rawLine, in: text)
            }
            guard !parts.isEmpty else { continue }
            return [resource(
                event: "Turn complete",
                matcher: nil,
                command: parts.joined(separator: " "),
                program: parts[0],
                key: "notify",
                file: file,
                agent: .codex,
                scope: .global
            )]
        }
        return []
    }

    static func resource(
        event: String,
        matcher: String?,
        command: String,
        program: String? = nil,
        key: String,
        file: URL,
        agent: AgentApp,
        scope: ResourceScope
    ) -> AgentResource {
        let readable = readableEvent(event)
        var details = [
            ResourceDetail(label: "When", value: readable),
            ResourceDetail(label: "Runs", value: SecretRedactor.redact(command), isCode: true),
        ]
        if let matcher, !matcher.isEmpty {
            details.insert(ResourceDetail(label: "Only for", value: matcher, isCode: true), at: 1)
        }
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return AgentResource(
            id: "hook:" + file.path(percentEncoded: false) + "#" + key,
            kind: .hooks,
            agent: agent,
            scope: scope,
            name: matcher.map { $0.isEmpty ? readable : "\(readable) · \($0)" } ?? readable,
            summary: SecretRedactor.redact(command),
            fileURL: file,
            configKey: key,
            details: details,
            modifiedAt: modified ?? .distantPast,
            problem: missingScriptProblem(program: program ?? firstWord(of: command), relativeTo: file)
        )
    }

    /// "PreToolUse" → "Pre Tool Use", "afterFileEdit" → "After File Edit"
    static func readableEvent(_ event: String) -> String {
        var words = ""
        for (index, character) in event.enumerated() {
            if index > 0, character.isUppercase { words.append(" ") }
            words.append(index == 0 ? Character(character.uppercased()) : character)
        }
        return words
    }

    /// A hook that points at a script file which no longer exists fails on every run.
    /// The program a shell command line starts with, honoring quotes around paths with spaces.
    static func firstWord(of command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if let quote = trimmed.first, quote == "\"" || quote == "'" {
            let rest = trimmed.dropFirst()
            return String(rest.prefix { $0 != quote })
        }
        return String(trimmed.prefix { $0 != " " })
    }

    static func missingScriptProblem(program first: String, relativeTo file: URL) -> String? {
        let looksLikePath = first.hasPrefix("/") || first.hasPrefix("./") || first.hasPrefix("~/")
        guard looksLikePath, !first.contains("$") else { return nil }

        let path: String
        if first.hasPrefix("~/") {
            path = URL.homeDirectory.appending(path: String(first.dropFirst(2))).path(percentEncoded: false)
        } else if first.hasPrefix("./") {
            path = file.deletingLastPathComponent().appending(path: String(first.dropFirst(2))).path(percentEncoded: false)
        } else {
            path = first
        }
        return FileManager.default.fileExists(atPath: path) ? nil : "The script \(first) doesn't exist, so this hook fails every time it runs."
    }

    private static func multilineArray(after line: Substring, in text: String) -> [String] {
        guard let start = text.range(of: line) else { return [] }
        let rest = text[start.upperBound...]
        guard let close = rest.firstIndex(of: "]") else { return [] }
        return rest[..<close]
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .compactMap { TOMLTables.string($0.trimmingCharacters(in: .whitespaces)) }
    }
}
