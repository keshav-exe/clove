import Foundation

/// What one app, or one command you started, costs right now: Cursor with all
/// its helpers, Xcode with its compilers, `npm run dev` in my-site.
struct AppActivity: Identifiable, Hashable, Sendable {
    struct Member: Identifiable, Hashable, Sendable {
        let pid: Int32
        let name: String
        let cpu: Double
        let memoryBytes: Int64
        var id: Int32 { pid }
    }

    enum Kind: Hashable, Sendable {
        /// An app in the Dock, and everything it started.
        case app(bundlePath: String, bundleID: String?)
        /// A command started from a terminal or by launchd, and its children.
        case command
    }

    let id: String
    let kind: Kind
    let name: String
    /// The process to stop for a command; the app's own process for an app.
    let rootPID: Int32
    var folder: String?
    /// Percent of one core, so a busy compiler on four cores reads 400%.
    let cpu: Double
    let memoryBytes: Int64
    /// Its busiest processes, most first.
    let members: [Member]
    let processCount: Int
    let isClove: Bool

    var bundlePath: String? {
        if case .app(let path, _) = kind { return path }
        return nil
    }
}

/// A running app Clove can name: Dock apps, by bundle path.
struct RunningAppInfo: Sendable {
    let name: String
    let bundleID: String?
}

enum ActivityReport {
    /// Where a command line starts: everything above it is just the window it runs in.
    static let shells: Set<String> = ["zsh", "bash", "sh", "fish", "dash", "nu", "login", "tmux", "screen", "-zsh", "-bash", "-fish", "-sh"]

    /// Terminals host commands rather than own them: `claude` running in
    /// Ghostty is Claude Code, not Ghostty.
    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        "dev.warp.Warp", "net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm", "co.zeit.hyper",
    ]

    /// Groups a look's processes by app or command, with each one's share of the
    /// processor since the previous look. Without one, processor use reads 0.
    static func build(
        current: ProcessSample,
        previous: ProcessSample?,
        apps: [String: RunningAppInfo],
        ownPID: Int32,
        folder: (Int32) -> String? = { _ in nil }
    ) -> [AppActivity] {
        let table = current.table
        let elapsed = previous.map { Double(current.takenAt &- $0.takenAt) } ?? 0

        func cpu(_ pid: Int32) -> Double {
            guard elapsed > 0, let now = current.cpuTime[pid], let then = previous?.cpuTime[pid], now >= then else { return 0 }
            return Double(now - then) / elapsed * 100
        }

        struct Bucket {
            var kind: AppActivity.Kind
            var root: Int32
            var name: String
            var members: [AppActivity.Member] = []
        }
        var buckets: [String: Bucket] = [:]

        for entry in table.entries.values {
            let (key, kind, root) = owner(of: entry, table: table, apps: apps)
            let member = AppActivity.Member(
                pid: entry.pid,
                name: RunningScanner.agentName(entry) ?? entry.program,
                cpu: cpu(entry.pid),
                memoryBytes: entry.residentKB * 1024
            )
            if buckets[key] == nil {
                let name: String = switch kind {
                case .app(let path, _): apps[path]?.name ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                case .command: table.entries[root].map { RunningScanner.agentName($0) ?? $0.program } ?? entry.program
                }
                buckets[key] = Bucket(kind: kind, root: root, name: name)
            }
            buckets[key]?.members.append(member)
        }

        let ownBundle = table.entries[ownPID].flatMap { outerBundle($0.executable ?? $0.args) }
        let groups = buckets.map { key, bucket in
            let members = bucket.members.sorted { ($0.cpu, $0.memoryBytes) > ($1.cpu, $1.memoryBytes) }
            let isClove: Bool = switch bucket.kind {
            case .app(let path, _): path == ownBundle
            case .command: false
            }
            return AppActivity(
                id: key,
                kind: bucket.kind,
                name: bucket.name,
                rootPID: bucket.root,
                folder: nil,
                cpu: members.reduce(0) { $0 + $1.cpu },
                memoryBytes: members.reduce(0) { $0 + $1.memoryBytes },
                members: Array(members.prefix(6)),
                processCount: members.count,
                isClove: isClove
            )
        }
        var sorted = groups.sorted { ($0.cpu, $0.memoryBytes) > ($1.cpu, $1.memoryBytes) }
        // Commands are only recognisable with their folder; look it up for the ones likely shown.
        for index in sorted.indices.prefix(24) where sorted[index].kind == .command {
            sorted[index].folder = folder(sorted[index].rootPID)
        }
        return sorted
    }

    /// The app a process belongs to, or the command it's part of. Walks up from
    /// the process: a Dock app owns it, unless that app is a terminal; a shell
    /// marks where a command begins.
    static func owner(of entry: ProcessTable.Entry, table: ProcessTable, apps: [String: RunningAppInfo]) -> (key: String, kind: AppActivity.Kind, root: Int32) {
        // A shell itself is part of the window it's open in.
        let isShell = shells.contains(entry.program)
        var root = entry
        for node in [entry] + table.ancestors(of: entry.pid) {
            if let bundle = outerBundle(node.executable ?? node.args), let app = apps[bundle] {
                let hostsCommands = app.bundleID.map(terminals.contains) ?? false
                if !hostsCommands || node.pid == entry.pid || isShell {
                    return ("app:" + bundle, .app(bundlePath: bundle, bundleID: app.bundleID), node.pid)
                }
                break
            }
            if !isShell, node.pid != entry.pid, shells.contains(node.program) { break }
            root = node
        }
        return ("pid:\(root.pid)", .command, root.pid)
    }

    /// `/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/…` → `/Applications/Cursor.app`.
    static func outerBundle(_ path: String) -> String? {
        guard path.hasPrefix("/") else { return nil }
        if let range = path.range(of: ".app/") { return String(path[..<range.lowerBound]) + ".app" }
        return path.hasSuffix(".app") ? path : nil
    }
}
