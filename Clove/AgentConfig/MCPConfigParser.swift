import Foundation

/// MCP servers from every format agents store them in. Environment variables
/// and headers often hold API keys, so only their names are kept.
enum MCPConfigParser {
    /// `{"mcpServers": {...}}`, used by Claude Code, Cursor, Gemini, Claude Desktop, and `.mcp.json`.
    static func servers(inJSON data: Data, file: URL, agent: AgentApp, scope: ResourceScope, keyPath: [String] = []) -> [AgentResource] {
        guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        for key in keyPath {
            guard let next = object[key] as? [String: Any] else { return [] }
            object = next
        }
        guard let servers = object["mcpServers"] as? [String: Any] else { return [] }
        return servers.compactMap { name, value in
            guard let config = value as? [String: Any] else { return nil }
            return resource(name: name, config: config, file: file, agent: agent, scope: scope)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// `[mcp_servers.<name>]` tables in Codex's config.toml.
    static func servers(inTOML text: String, file: URL, scope: ResourceScope) -> [AgentResource] {
        TOMLTables.tables(in: text, prefix: "mcp_servers")
            .map { name, values in
                var config: [String: Any] = [:]
                config["command"] = values["command"].flatMap(TOMLTables.string)
                config["url"] = values["url"].flatMap(TOMLTables.string)
                config["args"] = values["args"].map(TOMLTables.array)
                config["enabled"] = values["enabled"].map { $0 == "true" }
                return resource(name: name, config: config, file: file, agent: .codex, scope: scope, subtableKeys: TOMLTables.subtableKeys(in: text, table: "mcp_servers", name: name))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func resource(
        name: String,
        config: [String: Any],
        file: URL,
        agent: AgentApp,
        scope: ResourceScope,
        subtableKeys: [String] = []
    ) -> AgentResource {
        var details: [ResourceDetail] = []
        let url = config["url"] as? String ?? config["serverUrl"] as? String ?? config["httpUrl"] as? String
        let command = config["command"] as? String
        let args = (config["args"] as? [Any])?.map { "\($0)" } ?? []

        let transport: String
        if let url {
            transport = (config["type"] as? String)?.uppercased() == "SSE" ? "SSE" : "HTTP"
            details.append(ResourceDetail(label: "URL", value: SecretRedactor.redact(stripQuery(url)), isCode: true))
        } else {
            transport = "Local process"
        }
        details.insert(ResourceDetail(label: "Connects by", value: transport), at: 0)

        if let command {
            let line = ([command] + args).joined(separator: " ")
            details.append(ResourceDetail(label: "Runs", value: SecretRedactor.redact(line), isCode: true))
        }

        let envKeys = ((config["env"] as? [String: Any])?.keys).map(Array.init) ?? []
        let headerKeys = ((config["headers"] as? [String: Any])?.keys).map(Array.init) ?? []
        let hiddenKeys = (envKeys + headerKeys + subtableKeys).sorted()
        if !hiddenKeys.isEmpty {
            details.append(ResourceDetail(label: "Settings", value: hiddenKeys.joined(separator: ", ") + " (values hidden)"))
        }

        let isDisabled = config["disabled"] as? Bool == true || config["enabled"] as? Bool == false
        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        return AgentResource(
            id: "mcp:" + file.path(percentEncoded: false) + "#" + name,
            kind: .mcpServers,
            agent: agent,
            scope: scope,
            name: name,
            summary: isDisabled ? "Turned off" : (url.map { host(of: $0) } ?? command.map { (($0 as NSString).lastPathComponent) } ?? ""),
            fileURL: file,
            configKey: name,
            details: details,
            modifiedAt: modified ?? .distantPast
        )
    }

    /// Query strings on server URLs often carry keys.
    private static func stripQuery(_ url: String) -> String {
        guard let index = url.firstIndex(of: "?") else { return url }
        return String(url[..<index]) + "?" + SecretRedactor.mask
    }

    private static func host(of url: String) -> String {
        URL(string: url)?.host() ?? url
    }
}
