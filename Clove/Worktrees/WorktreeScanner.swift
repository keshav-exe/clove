import Foundation

/// Finds git worktrees in the projects Clove knows and the places agents make
/// them, and reads each one's state with read-only git commands. Removal goes
/// through `git worktree remove`, never a plain delete.
enum WorktreeScanner {
    /// Folders agents keep their worktrees in, outside the repo itself:
    /// `<root>/<repo>/<worktree>` or `<root>/<worktree>`.
    static let agentRoots = [".codex/worktrees", ".cursor/worktrees", "conductor/workspaces"]

    @concurrent
    static func scan(projectContainers: [URL], home: URL = .homeDirectory) async -> [GitRepository] {
        guard Git.path != nil else { return [] }
        let repositories = repositoryFolders(projectContainers: projectContainers, home: home)
        let folders = workingFolders(Git.run("/usr/sbin/lsof", ["-d", "cwd", "-Fpcn"]).output, excluding: getpid())

        let found = await withTaskGroup(of: GitRepository?.self) { group in
            for url in repositories {
                group.addTask { await repository(at: url, folders: folders, home: home) }
            }
            var results: [GitRepository] = []
            for await repository in group {
                if let repository { results.append(repository) }
            }
            return results
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Finding repositories

    /// Main worktree folders: projects one level inside each container, and the
    /// repos that worktrees in agent folders belong to.
    static func repositoryFolders(projectContainers: [URL], home: URL) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        func add(_ url: URL) {
            let key = url.standardizedFileURL.path(percentEncoded: false)
            if seen.insert(key).inserted { result.append(url.standardizedFileURL) }
        }

        for container in projectContainers {
            for folder in children(of: container) {
                if let repo = mainRepository(of: folder) { add(repo) }
            }
        }
        for root in agentRoots.map({ home.appending(path: $0) }) {
            for folder in children(of: root) {
                if let repo = mainRepository(of: folder) {
                    add(repo)
                    continue
                }
                for nested in children(of: folder) {
                    if let repo = mainRepository(of: nested) { add(repo) }
                }
            }
        }
        return result
    }

    /// The main worktree a folder belongs to: itself when `.git` is a folder,
    /// or the repo its `.git` file points into.
    static func mainRepository(of folder: URL) -> URL? {
        let dotGit = folder.appending(path: ".git")
        guard let values = try? dotGit.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey]) else { return nil }
        if values.isDirectory == true { return folder }
        guard values.isRegularFile == true, let contents = try? String(contentsOf: dotGit, encoding: .utf8) else { return nil }
        return GitPorcelain.mainRepository(fromGitFile: contents, relativeTo: folder)
    }

    // MARK: - Reading one repository

    @concurrent
    static func repository(at url: URL, folders: [(name: String, path: String)], home: URL) async -> GitRepository? {
        let list = Git.git(["worktree", "list", "--porcelain"], in: url)
        guard list.status == 0 else { return nil }
        let records = GitPorcelain.worktrees(list.output)
        // Only repos that have worktrees beyond the main checkout.
        guard records.count > 1, let main = records.first else { return nil }

        let branches = Set(Git.git(["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: url).output
            .split(separator: "\n").map(String.init))
        let originHead = Git.git(["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"], in: url).output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultBranch = GitPorcelain.defaultBranch(
            mainBranch: main.branch,
            originHead: originHead.isEmpty ? nil : originHead,
            localBranches: branches
        )
        // The local default branch, then its copy on origin, which may have merges not pulled yet.
        let bases: [String] = defaultBranch.map { branch in
            let hasOrigin = Git.git(["rev-parse", "--verify", "--quiet", "refs/remotes/origin/\(branch)"], in: url).status == 0
            return hasOrigin ? [branch, "origin/\(branch)"] : [branch]
        } ?? []

        let worktrees = await withTaskGroup(of: GitWorktree.self) { group in
            for (index, record) in records.enumerated() {
                group.addTask {
                    worktree(record, isMain: index == 0, repository: url, bases: bases, folders: folders, home: home)
                }
            }
            var results: [GitWorktree] = []
            for await worktree in group { results.append(worktree) }
            return results
        }
        let sorted = worktrees.sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain { return lhs.isMain }
            return (lhs.lastCommit ?? .distantPast) > (rhs.lastCommit ?? .distantPast)
        }
        return GitRepository(url: URL(filePath: main.path), defaultBranch: defaultBranch, worktrees: sorted)
    }

    static func worktree(
        _ record: GitPorcelain.WorktreeRecord,
        isMain: Bool,
        repository: URL,
        bases: [String],
        folders: [(name: String, path: String)],
        home: URL
    ) -> GitWorktree {
        let url = URL(filePath: record.path)
        let isMissing = record.isPrunable || !FileManager.default.fileExists(atPath: record.path)
        let agent = GitPorcelain.agent(path: record.path, branch: record.branch, home: home.path(percentEncoded: false))

        guard !isMissing else {
            return GitWorktree(
                url: url, repositoryURL: repository, isMain: isMain, branch: record.branch, head: record.head,
                isLocked: record.isLocked, isMissing: true, lastCommit: nil, lastCommitSubject: nil,
                changes: WorktreeChanges(), ignoredKeepers: [], ahead: 0, behind: 0, isMerged: false,
                users: [], bytes: 0, agent: agent
            )
        }

        let log = Git.git(["log", "-1", "--format=%ct%x00%s", "HEAD"], in: url).output
        let logParts = log.trimmingCharacters(in: .newlines).split(separator: "\0", maxSplits: 1)
        let lastCommit = logParts.first.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
        let subject = logParts.count > 1 ? String(logParts[1]) : nil

        var ahead = 0
        var behind = 0
        var isMerged = false
        if let base = bases.first,
           let counts = GitPorcelain.aheadBehind(Git.git(["rev-list", "--left-right", "--count", "\(base)...HEAD"], in: url).output) {
            ahead = counts.ahead
            behind = counts.behind
            isMerged = ahead == 0 || bases.contains { contains(base: $0, in: url) }
        }

        let changes: WorktreeChanges
        let keepers: [String]
        let bytes: Int64
        if isMain {
            changes = WorktreeChanges()
            keepers = []
            bytes = 0
        } else {
            changes = GitPorcelain.changes(Git.git(["status", "--porcelain=v1", "-z", "--untracked-files=normal"], in: url).output)
            keepers = GitPorcelain.keepers(inIgnored: Git.git(
                ["ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory"], in: url
            ).output)
            bytes = LeftoverScanner.size(of: url, fileManager: FileManager())
        }

        return GitWorktree(
            url: url, repositoryURL: repository, isMain: isMain, branch: record.branch, head: record.head,
            isLocked: record.isLocked, isMissing: false, lastCommit: lastCommit, lastCommitSubject: subject,
            changes: changes, ignoredKeepers: keepers, ahead: ahead, behind: behind, isMerged: isMerged,
            users: isMain ? [] : users(of: url, folders: folders), bytes: bytes, agent: agent
        )
    }

    /// The base has everything HEAD has: merged normally, or squashed so that
    /// merging HEAD in would change nothing.
    private static func contains(base: String, in folder: URL) -> Bool {
        if Git.git(["merge-base", "--is-ancestor", "HEAD", base], in: folder).status == 0 { return true }
        let merged = Git.git(["merge-tree", "--write-tree", base, "HEAD"], in: folder)
        guard merged.status == 0, let tree = merged.output.split(separator: "\n").first else { return false }
        let baseTree = Git.git(["rev-parse", "\(base)^{tree}"], in: folder).output.trimmingCharacters(in: .whitespacesAndNewlines)
        return !baseTree.isEmpty && tree == baseTree
    }

    // MARK: - Removing

    /// Removes a linked worktree with `git worktree remove`, then prunes. The
    /// checks happen now, not at scan time: it must still be a linked worktree
    /// of its repo, and nothing may be working inside it. `force` lets git
    /// discard uncommitted changes; the caller has confirmed that by name.
    @concurrent
    static func remove(_ worktree: GitWorktree, force: Bool) async -> String? {
        let repository = worktree.repositoryURL
        let records = GitPorcelain.worktrees(Git.git(["worktree", "list", "--porcelain"], in: repository).output)
        let path = StorageSafety.trimmedPath(worktree.url)
        guard let index = records.firstIndex(where: { StorageSafety.trimmedPath(URL(filePath: $0.path)) == path }), index > 0 else {
            return "It's no longer a worktree of \(repository.lastPathComponent)."
        }
        if worktree.isMissing || records[index].isPrunable {
            let pruned = Git.git(["worktree", "prune"], in: repository)
            return pruned.status == 0 ? nil : pruned.error
        }
        let folders = workingFolders(Git.run("/usr/sbin/lsof", ["-d", "cwd", "-Fpcn"]).output, excluding: getpid())
        let users = users(of: worktree.url, folders: folders)
        if !users.isEmpty {
            return "\(ListFormatter.localizedString(byJoining: users)) is working in it. Quit it first."
        }
        let removed = Git.git(["worktree", "remove"] + (force ? ["--force"] : []) + [path], in: repository)
        _ = Git.git(["worktree", "prune"], in: repository)
        return removed.status == 0 ? nil : removed.error.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Who's using it

    /// `lsof -d cwd -Fpcn`: each process's command and working folder.
    static func workingFolders(_ output: String, excluding pid: Int32) -> [(name: String, path: String)] {
        var results: [(name: String, path: String)] = []
        var currentPID: Int32?
        var command = ""
        for line in output.split(separator: "\n") {
            switch line.first {
            case "p":
                currentPID = Int32(line.dropFirst())
                command = ""
            case "c":
                command = String(line.dropFirst())
            case "n":
                guard currentPID != pid else { continue }
                let path = String(line.dropFirst())
                if path != "/" { results.append((command, path)) }
            default:
                break
            }
        }
        return results
    }

    /// Readable names of the programs working inside `folder`, agents named as such.
    static func users(of folder: URL, folders: [(name: String, path: String)]) -> [String] {
        let root = realPath(folder)
        var names: [String] = []
        for entry in folders where entry.path == root || entry.path.hasPrefix(root + "/") {
            let name = RunningScanner.agentPrograms[entry.name] ?? entry.name
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    // MARK: - Helpers

    /// The path lsof reports: links resolved by the system, keeping `/private`,
    /// which `resolvingSymlinksInPath()` strips from `/private/tmp` and `/private/var`.
    static func realPath(_ url: URL) -> String {
        let path = url.path(percentEncoded: false)
        guard let resolved = realpath(path, nil) else { return StorageSafety.trimmedPath(url) }
        defer { free(resolved) }
        return String(cString: resolved)
    }


    private static func children(of folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
}

/// Runs git without prompts or optional locks, so a background look never
/// competes with the person's own git commands.
enum Git {
    struct Output: Sendable {
        let status: Int32
        let output: String
        let error: String
    }

    /// A git that won't ask to install the command line tools.
    static let path: String? = {
        let manager = FileManager.default
        for candidate in ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/Library/Developer/CommandLineTools/usr/bin/git"]
        where manager.isExecutableFile(atPath: candidate) {
            return candidate
        }
        let developer = run("/usr/bin/xcode-select", ["-p"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let xcodeGit = developer + "/usr/bin/git"
        return !developer.isEmpty && manager.isExecutableFile(atPath: xcodeGit) ? xcodeGit : nil
    }()

    static func git(_ arguments: [String], in folder: URL) -> Output {
        guard let path else { return Output(status: -1, output: "", error: "git isn't installed") }
        return run(path, ["-C", folder.path(percentEncoded: false)] + arguments)
    }

    static func run(_ executable: String, _ arguments: [String]) -> Output {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["LC_ALL"] = "C"
        process.environment = environment
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return Output(status: -1, output: "", error: error.localizedDescription)
        }
        // git's errors are a line or two, so reading stderr second can't stall it.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Output(
            status: process.terminationStatus,
            output: String(decoding: data, as: UTF8.self),
            error: String(decoding: errorData, as: UTF8.self)
        )
    }
}
