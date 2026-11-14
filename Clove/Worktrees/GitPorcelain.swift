import Foundation

/// Parsers for git's machine-readable output. Pure, so they're tested without a repo.
enum GitPorcelain {
    /// One record of `git worktree list --porcelain`.
    struct WorktreeRecord: Hashable, Sendable {
        var path: String
        var head: String = ""
        /// Short name: "refs/heads/claude/fix" → "claude/fix".
        var branch: String?
        var isBare = false
        var isDetached = false
        var isLocked = false
        var isPrunable = false
    }

    /// Records are blank-line separated; the first is the main worktree.
    static func worktrees(_ output: String) -> [WorktreeRecord] {
        var records: [WorktreeRecord] = []
        var current: WorktreeRecord?
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty {
                if let record = current { records.append(record) }
                current = nil
                continue
            }
            let (key, value) = split(line)
            if key == "worktree" {
                if let record = current { records.append(record) }
                current = WorktreeRecord(path: value)
                continue
            }
            guard current != nil else { continue }
            switch key {
            case "HEAD": current?.head = value
            case "branch": current?.branch = value.hasPrefix("refs/heads/") ? String(value.dropFirst("refs/heads/".count)) : value
            case "bare": current?.isBare = true
            case "detached": current?.isDetached = true
            case "locked": current?.isLocked = true
            case "prunable": current?.isPrunable = true
            default: break
            }
        }
        if let record = current { records.append(record) }
        return records
    }

    /// `git status --porcelain=v1 -z`: `XY path`, NUL-separated. A rename or
    /// copy carries its old path as the next field. Ignored entries are skipped.
    static func changes(_ output: String) -> WorktreeChanges {
        var changes = WorktreeChanges()
        var fields = output.split(separator: "\0", omittingEmptySubsequences: true).makeIterator()
        while let field = fields.next() {
            guard field.count > 3 else { continue }
            let code = field.prefix(2)
            let path = String(field.dropFirst(3))
            switch code {
            case "??": changes.untracked.append(path)
            case "!!": continue
            default:
                changes.modified.append(path)
                if code.contains("R") || code.contains("C") { _ = fields.next() }
            }
        }
        return changes
    }

    /// `git rev-list --left-right --count <base>...HEAD`: "behind\tahead".
    static func aheadBehind(_ output: String) -> (ahead: Int, behind: Int)? {
        let numbers = output.split { $0 == "\t" || $0 == " " || $0 == "\n" }.compactMap { Int($0) }
        guard numbers.count == 2 else { return nil }
        return (ahead: numbers[1], behind: numbers[0])
    }

    /// The contents of a linked worktree's `.git` file, "gitdir: <repo>/.git/worktrees/<name>",
    /// to the main worktree's folder. Nil for anything else (submodules, plain repos).
    static func mainRepository(fromGitFile contents: String, relativeTo folder: URL) -> URL? {
        guard let line = contents.split(separator: "\n").first, line.hasPrefix("gitdir:") else { return nil }
        let raw = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        let gitDir = raw.hasPrefix("/") ? URL(filePath: raw) : folder.appending(path: raw)
        let standardized = gitDir.standardizedFileURL
        // <repo>/.git/worktrees/<name>
        let worktrees = standardized.deletingLastPathComponent()
        let dotGit = worktrees.deletingLastPathComponent()
        guard worktrees.lastPathComponent == "worktrees", dotGit.lastPathComponent == ".git" else { return nil }
        return dotGit.deletingLastPathComponent()
    }

    /// The trunk to measure against: the main checkout's branch when it's a
    /// usual trunk name, else what origin/HEAD points at, else main or master.
    static func defaultBranch(mainBranch: String?, originHead: String?, localBranches: Set<String>) -> String? {
        let trunks = ["main", "master", "trunk", "develop", "dev"]
        if let mainBranch, trunks.contains(mainBranch) { return mainBranch }
        if let originHead {
            let name = originHead.hasPrefix("origin/") ? String(originHead.dropFirst("origin/".count)) : originHead
            if localBranches.contains(name) { return name }
        }
        return trunks.first(where: localBranches.contains) ?? mainBranch
    }

    /// The agent that made a worktree, from where it lives or its branch prefix.
    static func agent(path: String, branch: String?, home: String) -> String? {
        let places: [(String, String)] = [
            ("/.claude/worktrees/", "Claude Code"),
            (home + "/.codex/worktrees/", "Codex"),
            (home + "/.cursor/worktrees/", "Cursor"),
            (home + "/conductor/workspaces/", "Conductor"),
            ("/.conductor/", "Conductor"),
        ]
        if let match = places.first(where: { path.contains($0.0) }) { return match.1 }
        let prefixes: [(String, String)] = [
            ("claude/", "Claude Code"), ("codex/", "Codex"), ("cursor/", "Cursor"),
            ("copilot/", "Copilot"), ("devin/", "Devin"), ("jules/", "Jules"),
        ]
        if let branch, let match = prefixes.first(where: { branch.hasPrefix($0.0) }) { return match.1 }
        return nil
    }

    /// Ignored files worth warning about before a folder goes: local env and
    /// secrets files, which usually exist nowhere else.
    static func keepers(inIgnored output: String) -> [String] {
        output.split(separator: "\0").map(String.init).filter { path in
            guard !path.hasSuffix("/") else { return false }
            let name = (path as NSString).lastPathComponent
            if name.hasSuffix(".example") || name.hasSuffix(".sample") || name.hasSuffix(".template") { return false }
            return name.hasPrefix(".env") || name.hasSuffix(".pem") || name.hasSuffix(".key") || name == ".dev.vars"
        }
    }

    private static func split(_ line: Substring) -> (String, String) {
        guard let space = line.firstIndex(of: " ") else { return (String(line), "") }
        return (String(line[..<space]), String(line[line.index(after: space)...]))
    }
}
