import Foundation

/// One MCP server's full definition, secrets included, for copying it to
/// another agent. Never displayed: the UI shows `AgentResource.details`.
struct MCPServerConfig: Sendable, Equatable {
    var command: String?
    var args: [String] = []
    var url: String?
    var transport: String?
    var env: [String: String] = [:]
    var headers: [String: String] = [:]

    /// Reads the entry named `name` back out of the file it came from.
    static func load(from resource: AgentResource) -> MCPServerConfig? {
        guard resource.kind == .mcpServers, let name = resource.configKey else { return nil }
        if resource.fileURL.pathExtension == "toml" {
            guard let text = try? String(contentsOf: resource.fileURL, encoding: .utf8) else { return nil }
            return fromTOML(text, name: name)
        }
        guard
            let data = try? Data(contentsOf: resource.fileURL),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return fromJSONRoot(root, name: name, scope: resource.scope)
    }

    private static func fromJSONRoot(_ root: [String: Any], name: String, scope: ResourceScope) -> MCPServerConfig? {
        if let servers = root["mcpServers"] as? [String: Any], let entry = servers[name] as? [String: Any] {
            return fromJSON(entry)
        }
        // Claude Code keeps per-project servers under projects[path].mcpServers.
        for case let project as [String: Any] in (root["projects"] as? [String: Any])?.values.map({ $0 }) ?? [] {
            if let entry = (project["mcpServers"] as? [String: Any])?[name] as? [String: Any] {
                return fromJSON(entry)
            }
        }
        return nil
    }

    static func fromJSON(_ entry: [String: Any]) -> MCPServerConfig {
        MCPServerConfig(
            command: entry["command"] as? String,
            args: (entry["args"] as? [Any])?.map { "\($0)" } ?? [],
            url: entry["url"] as? String ?? entry["serverUrl"] as? String ?? entry["httpUrl"] as? String,
            transport: entry["type"] as? String,
            env: (entry["env"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:],
            headers: (entry["headers"] as? [String: Any])?.compactMapValues { $0 as? String } ?? [:]
        )
    }

    static func fromTOML(_ text: String, name: String) -> MCPServerConfig? {
        guard let values = TOMLTables.tables(in: text, prefix: "mcp_servers")[name] else { return nil }
        var config = MCPServerConfig(
            command: values["command"].flatMap(TOMLTables.string),
            args: values["args"].map(TOMLTables.array) ?? [],
            url: values["url"].flatMap(TOMLTables.string)
        )
        config.env = subtable(text, name: name, table: "env")
        config.headers = subtable(text, name: name, table: "http_headers")
        return config
    }

    private static func subtable(_ text: String, name: String, table: String) -> [String: String] {
        var values: [String: String] = [:]
        var inside = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inside = TOMLTables.headerPath(line) == ["mcp_servers", name, table]
                continue
            }
            guard inside, let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            values[key] = TOMLTables.string(value) ?? value
        }
        return values
    }

    enum WriteError: LocalizedError {
        case alreadyThere(String)

        var errorDescription: String? {
            switch self {
            case .alreadyThere(let name): "A server named “\(name)” is already set up there."
            }
        }
    }

    /// Adds this server to an `{"mcpServers": {…}}` file, creating it if needed.
    /// Other entries and keys are kept.
    func add(named name: String, toJSONFile file: URL) throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: file),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        guard servers[name] == nil else { throw WriteError.alreadyThere(name) }
        servers[name] = json
        root["mcpServers"] = servers

        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }

    // MARK: - Output

    /// The shape Cursor, Claude Code, Gemini, and `.mcp.json` all read.
    var json: [String: Any] {
        var entry: [String: Any] = [:]
        if let url {
            entry["url"] = url
            if let transport { entry["type"] = transport }
            if !headers.isEmpty { entry["headers"] = headers }
        } else if let command {
            entry["command"] = command
            entry["args"] = args
        }
        if !env.isEmpty { entry["env"] = env }
        return entry
    }

    /// `claude mcp add-json <name> '<json>' --scope user`
    func claudeCommand(name: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        let payload = String(decoding: data, as: UTF8.self).replacing("'", with: "'\\''")
        return "claude mcp add-json \(Self.shellQuoted(name)) '\(payload)' --scope user"
    }

    /// A `[mcp_servers.<name>]` table to paste into ~/.codex/config.toml.
    func codexTOML(name: String) -> String {
        var lines = ["[mcp_servers.\(Self.tomlKey(name))]"]
        if let url {
            lines.append("url = \(Self.tomlString(url))")
        } else if let command {
            lines.append("command = \(Self.tomlString(command))")
            lines.append("args = [\(args.map(Self.tomlString).joined(separator: ", "))]")
        }
        if !env.isEmpty {
            lines.append("")
            lines.append("[mcp_servers.\(Self.tomlKey(name)).env]")
            for (key, value) in env.sorted(by: { $0.key < $1.key }) {
                lines.append("\(Self.tomlKey(key)) = \(Self.tomlString(value))")
            }
        }
        if !headers.isEmpty {
            lines.append("")
            lines.append("[mcp_servers.\(Self.tomlKey(name)).http_headers]")
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                lines.append("\(Self.tomlKey(key)) = \(Self.tomlString(value))")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func tomlString(_ value: String) -> String {
        "\"" + value.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"") + "\""
    }

    private static func tomlKey(_ key: String) -> String {
        key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") } ? key : tomlString(key)
    }

    private static func shellQuoted(_ value: String) -> String {
        value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            ? value
            : "'" + value.replacing("'", with: "'\\''") + "'"
    }
}
