import Foundation

/// Finds agent sessions, the MCP servers they started, and dev servers still
/// listening on a port, from one look at your processes.
enum RunningScanner {
    /// A configured MCP server's name and a piece of its command line to match on.
    struct KnownServer: Sendable {
        let name: String
        let signature: String
    }

    struct Scan: Sendable {
        let processes: [RunningProcess]
        let sample: ProcessSample
    }

    @concurrent
    static func scan(known: [KnownServer]) async -> Scan {
        let sample = await ProcessMonitor.shared.sample()
        let found = classify(table: sample.table, ports: sample.ports, known: known)
        let processes = found.map { item in
            RunningProcess(
                pid: item.pid, kind: item.kind, name: item.name, startedBy: item.startedBy,
                command: item.command, startedAt: item.startedAt, memoryBytes: item.memoryBytes,
                ports: item.ports, folder: ProcessMonitor.workingFolder(of: item.pid).map { URL(filePath: $0, directoryHint: .isDirectory) },
                owner: item.owner
            )
        }
        return Scan(processes: processes, sample: sample)
    }

    /// What kind each running server or agent is, and nothing else: the menu bar
    /// count needs no folders. Shares a recent look with anything else watching.
    @concurrent
    static func kinds(known: [KnownServer]) async -> [RunningProcess.Kind] {
        let sample = await ProcessMonitor.shared.sample(maxAge: .seconds(5))
        return classify(table: sample.table, ports: sample.ports, known: known).map(\.kind)
    }

    // MARK: - Classification

    static let agentPrograms: [String: String] = [
        "claude": "Claude Code",
        "codex": "Codex",
        "cursor-agent": "Cursor CLI",
        "gemini": "Gemini CLI",
        "opencode": "OpenCode",
        "aider": "Aider",
        "amp": "Amp",
        "droid": "Droid",
        "goose": "Goose",
    ]

    static let devRuntimes: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby", "php", "java", "go", "dotnet",
        "uvicorn", "gunicorn", "rails", "puma", "vite", "next-server", "esbuild", "hugo", "astro",
    ]

    /// Databases, proxies, and tunnels you run for development, often from
    /// `brew services`: worth a row like any dev server.
    static let devServices: Set<String> = [
        "postgres", "redis-server", "mysqld", "mariadbd", "mongod", "memcached", "nginx", "caddy",
        "httpd", "cloudflared", "ngrok", "minio", "meilisearch", "typesense-server", "ollama",
    ]

    /// What a port is for, where its program's name doesn't say.
    static func serviceName(program: String, ports: [Int]) -> String? {
        switch program {
        case "ControlCenter" where ports.contains(5000) || ports.contains(7000): "AirPlay Receiver"
        case "rapportd": "Continuity"
        case "sharingd": "Sharing"
        case "remoted": "Remote Access"
        default: nil
        }
    }

    static func classify(table: ProcessTable, ports: [Int32: [Int]], known: [KnownServer]) -> [RunningProcess] {
        var results: [RunningProcess] = []
        var claimed: Set<Int32> = []
        let now = Date.now

        func make(_ entry: ProcessTable.Entry, kind: RunningProcess.Kind, name: String, owner: PortOwner? = nil) -> RunningProcess {
            let tree = table.subtree(of: entry.pid)
            // An app's own sockets only: what it started may be listed on its own.
            let listening = kind == .appPort ? (ports[entry.pid] ?? []) : Array(Set(tree.flatMap { ports[$0.pid] ?? [] })).sorted()
            return RunningProcess(
                pid: entry.pid,
                kind: kind,
                name: name,
                startedBy: startedBy(table.ancestors(of: entry.pid)),
                command: SecretRedactor.redact(entry.args),
                startedAt: now.addingTimeInterval(-entry.elapsed),
                memoryBytes: tree.reduce(0) { $0 + $1.residentKB } * 1024,
                ports: listening,
                folder: nil,
                owner: owner
            )
        }

        let sorted = table.entries.values.sorted { $0.pid < $1.pid }

        // Agent sessions, skipping helpers an agent spawns of itself.
        for entry in sorted {
            guard let name = agentName(entry) else { continue }
            if table.ancestors(of: entry.pid).contains(where: { agentName($0) == name }) { continue }
            results.append(make(entry, kind: .agent, name: name))
            claimed.insert(entry.pid)
        }

        // MCP servers: the top of each chain, so `npm exec x` and its node child are one.
        for entry in sorted where isMCPServer(entry) {
            if table.ancestors(of: entry.pid).contains(where: isMCPServer) { continue }
            results.append(make(entry, kind: .mcpServer, name: serverName(entry, known: known)))
            for child in table.subtree(of: entry.pid) { claimed.insert(child.pid) }
        }

        // Dev servers: dev runtimes and services listening on a port, or
        // anything an agent started. A runtime an app ships for itself, like
        // Raycast's Node, belongs to that app instead.
        for entry in sorted where ports[entry.pid] != nil && !claimed.contains(entry.pid) {
            let ancestors = table.ancestors(of: entry.pid)
            if ancestors.contains(where: { claimed.contains($0.pid) && agentName($0) == nil }) { continue }
            let startedByAgent = ancestors.contains { agentName($0) != nil }
            let program = entry.program.lowercased()
            let isDevProgram = devRuntimes.contains(program) || devServices.contains(program)
            guard startedByAgent || (isDevProgram && !isBundled(entry)) else { continue }
            results.append(make(entry, kind: .devServer, name: entry.program, owner: appOwner(entry, ancestors: ancestors)))
            for child in table.subtree(of: entry.pid) { claimed.insert(child.pid) }
        }

        // App ports: what's left listening belongs to an app or to macOS.
        for entry in sorted where ports[entry.pid] != nil && !claimed.contains(entry.pid) {
            let ancestors = table.ancestors(of: entry.pid)
            if ancestors.contains(where: { claimed.contains($0.pid) }) { continue }
            guard let owner = portOwner(entry, ancestors: ancestors, ports: ports[entry.pid] ?? []) else { continue }
            results.append(make(entry, kind: .appPort, name: entry.program, owner: owner))
            for child in table.subtree(of: entry.pid) { claimed.insert(child.pid) }
        }
        return results
    }

    // MARK: - Owners

    static let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/bin/"]

    /// "/Applications/Raycast.app/Contents/MacOS/Raycast" → "/Applications/Raycast.app".
    /// A framework's stub app, like Python.framework's Python.app, isn't an app.
    static func bundlePath(of path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        let bundle = String(path[..<range.lowerBound]) + ".app"
        return bundle.contains(".framework/") ? nil : bundle
    }

    /// A program an app installed for its own use: inside its bundle or its
    /// Application Support folder.
    static func isBundled(_ entry: ProcessTable.Entry) -> Bool {
        let path = entry.executable ?? entry.args
        return bundlePath(of: path) != nil || path.contains("/Library/Application Support/")
    }

    /// The app that started a process, stopping at a shell: `npm run dev` in
    /// Cursor's terminal is yours, not Cursor's.
    static func appOwner(_ entry: ProcessTable.Entry, ancestors: [ProcessTable.Entry]) -> PortOwner? {
        for item in [entry] + ancestors {
            if ActivityReport.shells.contains(item.program) { return nil }
            let path = item.executable ?? item.args
            if let bundle = bundlePath(of: path) {
                return PortOwner(name: appName(bundle), bundlePath: bundle, isSystem: systemPrefixes.contains(where: path.hasPrefix))
            }
        }
        return nil
    }

    /// Who a leftover listener belongs to: an app, a part of macOS, or no one
    /// Clove can name, which stays out of the list.
    static func portOwner(_ entry: ProcessTable.Entry, ancestors: [ProcessTable.Entry], ports: [Int]) -> PortOwner? {
        let path = entry.executable ?? entry.args
        let isSystem = systemPrefixes.contains(where: path.hasPrefix)
        if let service = serviceName(program: entry.program, ports: ports) {
            return PortOwner(name: service, bundlePath: bundlePath(of: path), isSystem: isSystem)
        }
        if let owner = appOwner(entry, ancestors: ancestors) { return owner }
        return isSystem ? PortOwner(name: entry.program, bundlePath: nil, isSystem: true) : nil
    }

    /// The name Finder shows, without ".app".
    static func appName(_ bundle: String) -> String {
        let shown = FileManager.default.displayName(atPath: bundle)
        return shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown
    }

    static func agentName(_ entry: ProcessTable.Entry) -> String? {
        if let name = agentPrograms[entry.program] { return name }
        if entry.program == "node", entry.args.contains("gemini-cli") { return "Gemini CLI" }
        return nil
    }

    /// Words in the command line, split on spaces, slashes, and @: "@playwright/mcp@latest" → playwright, mcp, latest.
    static func isMCPServer(_ entry: ProcessTable.Entry) -> Bool {
        // App helper processes (Cursor's MCP host, Electron plugin hosts) and
        // the system's own tools are never servers an agent added.
        // Most processes never mention MCP: skip them before the costlier checks.
        guard entry.args.range(of: "mcp", options: .caseInsensitive) != nil else { return false }
        if entry.args.hasPrefix("Cursor Helper") || entry.program.contains(" Helper") { return false }
        let path = entry.executable ?? entry.args
        if ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/"].contains(where: path.hasPrefix) { return false }
        let words = entry.args.lowercased().split { " /@=".contains($0) }
        return words.contains { word in
            word == "mcp" || word.hasPrefix("mcp-") || word.hasSuffix("-mcp")
                || word.hasPrefix("mcp_") || word.hasSuffix("_mcp")
        }
    }

    static func serverName(_ entry: ProcessTable.Entry, known: [KnownServer]) -> String {
        if let match = known.first(where: { !$0.signature.isEmpty && entry.args.contains($0.signature) }) {
            return match.name
        }
        let words = entry.args.split(separator: " ").map(String.init)
        // npm exec <pkg>, npx -y <pkg>, uvx <pkg>
        if let index = words.firstIndex(where: { ["exec", "npx", "uvx", "bunx", "dlx"].contains($0) }) {
            if let package = words[(index + 1)...].first(where: { !$0.hasPrefix("-") }) {
                return packageName(package)
            }
        }
        if let bin = words.first(where: { $0.contains("/node_modules/.bin/") }) {
            return (bin as NSString).lastPathComponent
        }
        return entry.program
    }

    /// "@playwright/mcp@latest" → "@playwright/mcp", "shadcn@latest" → "shadcn"
    static func packageName(_ raw: String) -> String {
        let body = raw.hasPrefix("@") ? String(raw.dropFirst()) : raw
        let name = body.split(separator: "@").first.map(String.init) ?? body
        return raw.hasPrefix("@") ? "@" + name : name
    }

    static func startedBy(_ ancestors: [ProcessTable.Entry]) -> String? {
        for entry in ancestors {
            if let agent = agentName(entry) { return agent }
            if entry.args.contains("Cursor.app") || entry.args.hasPrefix("Cursor Helper") { return "Cursor" }
            if entry.args.contains("/Claude.app/") { return "Claude" }
            if entry.args.contains("Visual Studio Code.app") { return "VS Code" }
            if entry.args.contains("Windsurf.app") { return "Windsurf" }
            if ["Terminal", "iTerm2", "Warp", "ghostty", "kitty", "alacritty", "WezTerm"].contains(where: entry.args.contains) {
                return "Terminal"
            }
        }
        return nil
    }
}
