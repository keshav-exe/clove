import Foundation

/// Finds agent sessions, the MCP servers they started, and dev servers still
/// listening on a port, from one `ps` and one `lsof` snapshot.
enum RunningScanner {
    /// A configured MCP server's name and a piece of its command line to match on.
    struct KnownServer: Sendable {
        let name: String
        let signature: String
    }

    @concurrent
    static func scan(known: [KnownServer]) async -> [RunningProcess] {
        let table = ProcessTable.parse(
            run("/bin/ps", ["-axo", "pid=,ppid=,etime=,rss=,args="]),
            executables: run("/bin/ps", ["-axo", "pid=,comm="])
        )
        let ports = listeningPorts(run("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"]))
        let found = classify(table: table, ports: ports, known: known)
        let folders = workingFolders(for: found.map(\.pid))
        return found.map { item in
            RunningProcess(
                pid: item.pid, kind: item.kind, name: item.name, startedBy: item.startedBy,
                command: item.command, startedAt: item.startedAt, memoryBytes: item.memoryBytes,
                ports: item.ports, folder: folders[item.pid]
            )
        }
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

    static func classify(table: ProcessTable, ports: [Int32: [Int]], known: [KnownServer]) -> [RunningProcess] {
        var results: [RunningProcess] = []
        var claimed: Set<Int32> = []
        let now = Date.now

        func make(_ entry: ProcessTable.Entry, kind: RunningProcess.Kind, name: String) -> RunningProcess {
            let tree = table.subtree(of: entry.pid)
            return RunningProcess(
                pid: entry.pid,
                kind: kind,
                name: name,
                startedBy: startedBy(table.ancestors(of: entry.pid)),
                command: SecretRedactor.redact(entry.args),
                startedAt: now.addingTimeInterval(-entry.elapsed),
                memoryBytes: tree.reduce(0) { $0 + $1.residentKB } * 1024,
                ports: Array(Set(tree.flatMap { ports[$0.pid] ?? [] })).sorted(),
                folder: nil
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

        // Dev servers: dev runtimes listening on a port, or anything an agent started.
        for entry in sorted where ports[entry.pid] != nil && !claimed.contains(entry.pid) {
            let ancestors = table.ancestors(of: entry.pid)
            if ancestors.contains(where: { claimed.contains($0.pid) && agentName($0) == nil }) { continue }
            let startedByAgent = ancestors.contains { agentName($0) != nil }
            let isAppHelper = entry.args.contains(".app/Contents/")
            guard startedByAgent || (devRuntimes.contains(entry.program) && !isAppHelper) else { continue }
            results.append(make(entry, kind: .devServer, name: entry.program))
            for child in table.subtree(of: entry.pid) { claimed.insert(child.pid) }
        }
        return results
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

    // MARK: - System tools

    /// `lsof -Fpn` output: `p<pid>` then `n<address:port>` lines.
    static func listeningPorts(_ output: String) -> [Int32: [Int]] {
        var ports: [Int32: Set<Int>] = [:]
        var current: Int32?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                current = Int32(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = current,
                      let colon = line.lastIndex(of: ":"), let port = Int(line[line.index(after: colon)...]) {
                ports[pid, default: []].insert(port)
            }
        }
        return ports.mapValues { $0.sorted() }
    }

    private static func workingFolders(for pids: [Int32]) -> [Int32: URL] {
        guard !pids.isEmpty else { return [:] }
        let output = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fpn", "-p", pids.map(String.init).joined(separator: ",")])
        var folders: [Int32: URL] = [:]
        var current: Int32?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                current = Int32(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = current {
                let path = String(line.dropFirst())
                if path != "/" { folders[pid] = URL(filePath: path) }
            }
        }
        return folders
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
