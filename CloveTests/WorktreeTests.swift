import Foundation
import Testing
@testable import Clove

struct WorktreePorcelainTests {
    @Test func parsesWorktreeList() {
        let output = """
        worktree /Users/me/Developer/clove
        HEAD 17e8916cece6a1001910f88b3ed5c7ccfdb96e39
        branch refs/heads/main

        worktree /Users/me/Developer/clove/.claude/worktrees/fix-nav
        HEAD 3811f2d588286cf6e2ccfde6e6b54daaab12e7a6
        branch refs/heads/claude/fix-nav
        locked agent is running

        worktree /tmp/scratch
        HEAD 3811f2d588286cf6e2ccfde6e6b54daaab12e7a6
        detached
        prunable gitdir file points to non-existent location

        """
        let records = GitPorcelain.worktrees(output)
        #expect(records.count == 3)
        #expect(records[0].path == "/Users/me/Developer/clove")
        #expect(records[0].branch == "main")
        #expect(records[1].branch == "claude/fix-nav")
        #expect(records[1].isLocked)
        #expect(!records[1].isPrunable)
        #expect(records[2].branch == nil)
        #expect(records[2].isDetached)
        #expect(records[2].isPrunable)
    }

    @Test func parsesBareAndUnterminatedLists() {
        let records = GitPorcelain.worktrees("worktree /srv/repo.git\nbare\n\nworktree /srv/wt\nHEAD abc\nbranch refs/heads/x")
        #expect(records.map(\.path) == ["/srv/repo.git", "/srv/wt"])
        #expect(records[0].isBare)
        #expect(records[1].branch == "x")
    }

    @Test func parsesStatusWithRenamesAndUntracked() {
        let output = " M Sources/App.swift\0R  New.swift\0Old.swift\0?? notes/\0A  added.txt\0!! build/\0"
        let changes = GitPorcelain.changes(output)
        #expect(changes.modified == ["Sources/App.swift", "New.swift", "added.txt"])
        #expect(changes.untracked == ["notes/"])
        #expect(changes.count == 4)
        #expect(changes.summary == "3 changed files and 1 new file")
        #expect(GitPorcelain.changes("").isEmpty)
    }

    @Test func parsesAheadBehind() {
        let counts = GitPorcelain.aheadBehind("12\t3\n")
        #expect(counts?.behind == 12)
        #expect(counts?.ahead == 3)
        #expect(GitPorcelain.aheadBehind("fatal: bad revision") == nil)
    }

    @Test func findsMainRepositoryFromGitFile() {
        let folder = URL(filePath: "/Users/me/Developer/clove/.claude/worktrees/fix")
        #expect(GitPorcelain.mainRepository(fromGitFile: "gitdir: /Users/me/Developer/clove/.git/worktrees/fix\n", relativeTo: folder)?.path == "/Users/me/Developer/clove")
        #expect(GitPorcelain.mainRepository(fromGitFile: "gitdir: ../../../.git/worktrees/fix", relativeTo: folder)?.path == "/Users/me/Developer/clove")
        // A submodule's .git file points into modules/, not worktrees/.
        #expect(GitPorcelain.mainRepository(fromGitFile: "gitdir: ../.git/modules/lib", relativeTo: folder) == nil)
        #expect(GitPorcelain.mainRepository(fromGitFile: "not a git file", relativeTo: folder) == nil)
    }

    @Test func picksTheDefaultBranch() {
        // The main checkout's trunk wins over a stale origin/HEAD.
        #expect(GitPorcelain.defaultBranch(mainBranch: "main", originHead: "origin/master", localBranches: ["main", "master"]) == "main")
        #expect(GitPorcelain.defaultBranch(mainBranch: "feature", originHead: "origin/develop", localBranches: ["develop", "main"]) == "develop")
        #expect(GitPorcelain.defaultBranch(mainBranch: "feature", originHead: nil, localBranches: ["master", "feature"]) == "master")
        #expect(GitPorcelain.defaultBranch(mainBranch: nil, originHead: nil, localBranches: []) == nil)
    }

    @Test func tellsWhichAgentMadeIt() {
        let home = "/Users/me"
        #expect(GitPorcelain.agent(path: "/Users/me/Developer/clove/.claude/worktrees/x", branch: "x", home: home) == "Claude Code")
        #expect(GitPorcelain.agent(path: "/Users/me/.codex/worktrees/ab12/clove", branch: nil, home: home) == "Codex")
        #expect(GitPorcelain.agent(path: "/Users/me/conductor/workspaces/clove/oslo", branch: "oslo", home: home) == "Conductor")
        #expect(GitPorcelain.agent(path: "/Users/me/Developer/clove/.worktrees/a", branch: "cursor/fix-a", home: home) == "Cursor")
        #expect(GitPorcelain.agent(path: "/Users/me/Developer/clove-two", branch: "feature", home: home) == nil)
    }

    @Test func keepsOnlyIgnoredFilesWorthWarningAbout() {
        let output = "node_modules/\0.env.local\0.env.example\0build/\0certs/dev.pem\0.DS_Store\0"
        #expect(GitPorcelain.keepers(inIgnored: output) == [".env.local", "certs/dev.pem"])
    }

    @Test func readsWorkingFoldersAndNamesAgents() {
        let output = "p10\ncclaude\nfcwd\nn/Users/me/Developer/clove/.claude/worktrees/fix\np11\nczsh\nfcwd\nn/Users/me/Developer/clove/.claude/worktrees/fix/src\np12\ncnode\nfcwd\nn/Users/me/Developer/clove/.claude/worktrees/fix-two\np13\ncClove\nfcwd\nn/Users/me/Developer/clove/.claude/worktrees/fix\n"
        let folders = WorktreeScanner.workingFolders(output, excluding: 13)
        #expect(folders.count == 3)
        let users = WorktreeScanner.users(of: URL(filePath: "/Users/me/Developer/clove/.claude/worktrees/fix"), folders: folders)
        // fix-two shares a prefix but is a different folder.
        #expect(users == ["Claude Code", "zsh"])
    }
}

struct WorktreeSafetyTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func worktree(
        isMain: Bool = false,
        branch: String? = "feature",
        isLocked: Bool = false,
        isMissing: Bool = false,
        lastCommitDaysAgo: Double = 1,
        changes: WorktreeChanges = WorktreeChanges(),
        ahead: Int = 2,
        isMerged: Bool = false,
        users: [String] = []
    ) -> GitWorktree {
        GitWorktree(
            url: URL(filePath: "/repo/.claude/worktrees/feature"), repositoryURL: URL(filePath: "/repo"),
            isMain: isMain, branch: branch, head: "abc1234", isLocked: isLocked, isMissing: isMissing,
            lastCommit: now.addingTimeInterval(-lastCommitDaysAgo * 86_400), lastCommitSubject: nil,
            changes: changes, ignoredKeepers: [], ahead: ahead, behind: 3, isMerged: isMerged,
            users: users, bytes: 1_000, agent: nil
        )
    }

    @Test func mergedAndCleanIsSafe() {
        #expect(WorktreeSafety.verdict(for: worktree(ahead: 0, isMerged: true), now: now) == .safe(.merged))
    }

    @Test func staleAndCleanIsSafeBecauseTheBranchKeepsItsCommits() {
        #expect(WorktreeSafety.verdict(for: worktree(lastCommitDaysAgo: 45), now: now) == .safe(.stale(days: 45)))
    }

    @Test func recentUnmergedWorkIsNotPicked() {
        let verdict = WorktreeSafety.verdict(for: worktree(lastCommitDaysAgo: 3), now: now)
        #expect(verdict == .active)
        #expect(!verdict.isSafe)
        #expect(verdict.isRemovable)
        #expect(!verdict.needsForce)
    }

    @Test func uncommittedChangesNeedForceEvenWhenMerged() {
        let changes = WorktreeChanges(modified: ["a.swift"], untracked: ["b.swift"])
        let verdict = WorktreeSafety.verdict(for: worktree(lastCommitDaysAgo: 90, changes: changes, isMerged: true), now: now)
        #expect(verdict == .unsaved(.changes(changes)))
        #expect(verdict.needsForce)
        #expect(verdict.lossDescription == "1 changed file and 1 new file that were never committed.")
    }

    @Test func detachedCommitsWouldBeLost() {
        let verdict = WorktreeSafety.verdict(for: worktree(branch: nil, lastCommitDaysAgo: 90, ahead: 2), now: now)
        #expect(verdict == .unsaved(.detachedCommits(2)))
        // A detached HEAD already in the default branch loses nothing.
        #expect(WorktreeSafety.verdict(for: worktree(branch: nil, ahead: 0, isMerged: true), now: now) == .safe(.merged))
    }

    @Test func inUseLockedAndMainAreBlocked() {
        #expect(WorktreeSafety.verdict(for: worktree(ahead: 0, isMerged: true, users: ["Claude Code"]), now: now) == .blocked(.inUse(["Claude Code"])))
        #expect(WorktreeSafety.verdict(for: worktree(isLocked: true, ahead: 0, isMerged: true), now: now) == .blocked(.locked))
        #expect(WorktreeSafety.verdict(for: worktree(isMain: true), now: now) == .blocked(.main))
        #expect(!WorktreeVerdict.blocked(.locked).isRemovable)
    }

    @Test func missingFolderIsSafeToPrune() {
        #expect(WorktreeSafety.verdict(for: worktree(isMissing: true, users: ["zsh"]), now: now) == .safe(.missing))
    }

    @Test func confirmationNamesWhatWouldBeLost() {
        let dirty = worktree(changes: WorktreeChanges(modified: ["a.swift", "b.swift"]))
        let clean = worktree(ahead: 0, isMerged: true)
        let removal = WorktreeRemoval([dirty, clean]) { WorktreeSafety.verdict(for: $0, now: now) }
        #expect(removal.losesWork)
        #expect(removal.title == "Remove 2 worktrees?")
        #expect(removal.message.contains("2 changed files that were never committed: a.swift and b.swift."))
        #expect(removal.confirmLabel == "Discard Work and Remove")

        let safe = WorktreeRemoval([clean]) { WorktreeSafety.verdict(for: $0, now: now) }
        #expect(!safe.losesWork)
        #expect(safe.confirmLabel == "Remove Worktree")
    }
}

/// Against a real repository in a temporary folder, with the git on this Mac.
struct WorktreeScannerTests {
    private func git(_ arguments: [String], in folder: URL) throws {
        let result = Git.git(arguments, in: folder)
        if result.status != 0 { throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: result.error]) }
    }

    @Test func scansAndRemovesWorktrees() async throws {
        try #require(Git.path != nil)
        let root = URL.temporaryDirectory.appending(path: "clove-wt-\(UUID().uuidString)").resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = root.appending(path: "projects/app")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)

        try git(["init", "-q", "-b", "main"], in: repo)
        try git(["config", "user.email", "test@example.com"], in: repo)
        try git(["config", "user.name", "Test"], in: repo)
        try Data("one".utf8).write(to: repo.appending(path: "README.md"))
        try git(["add", "."], in: repo)
        try git(["commit", "-q", "-m", "first"], in: repo)

        // merged: no commits of its own. dirty: an uncommitted file. ahead: two commits.
        try git(["worktree", "add", "-q", "-b", "claude/merged", ".claude/worktrees/merged"], in: repo)
        try git(["worktree", "add", "-q", "-b", "dirty", root.appending(path: "dirty").path(percentEncoded: false)], in: repo)
        try git(["worktree", "add", "-q", "-b", "ahead", root.appending(path: "ahead").path(percentEncoded: false)], in: repo)
        try Data("draft".utf8).write(to: root.appending(path: "dirty/draft.txt"))
        let ahead = root.appending(path: "ahead")
        for message in ["two", "three"] {
            try Data(message.utf8).write(to: ahead.appending(path: "\(message).txt"))
            try git(["add", "."], in: ahead)
            try git(["commit", "-q", "-m", message], in: ahead)
        }
        try Data("four".utf8).write(to: repo.appending(path: "four.txt"))
        try git(["add", "."], in: repo)
        try git(["commit", "-q", "-m", "four"], in: repo)

        let repositories = await WorktreeScanner.scan(projectContainers: [root.appending(path: "projects")], home: root)
        let repository = try #require(repositories.first)
        #expect(repositories.count == 1)
        #expect(repository.defaultBranch == "main")
        #expect(repository.worktrees.first?.isMain == true)

        let byName = Dictionary(uniqueKeysWithValues: repository.linked.map { ($0.name, $0) })
        let merged = try #require(byName["claude/merged"])
        #expect(merged.isMerged)
        #expect(merged.behind == 1)
        #expect(merged.agent == "Claude Code")
        #expect(WorktreeSafety.verdict(for: merged) == .safe(.merged))

        let dirty = try #require(byName["dirty"])
        #expect(dirty.changes.untracked == ["draft.txt"])
        #expect(WorktreeSafety.verdict(for: dirty).needsForce)

        let aheadTree = try #require(byName["ahead"])
        #expect(aheadTree.ahead == 2)
        #expect(aheadTree.behind == 1)
        #expect(!aheadTree.isMerged)
        #expect(WorktreeSafety.verdict(for: aheadTree) == .active)
        #expect(aheadTree.bytes > 0)

        // A process working inside it blocks it, matched on the real /private path.
        let folders = [(name: "sleep", path: WorktreeScanner.realPath(dirty.url))]
        #expect(WorktreeScanner.users(of: dirty.url, folders: folders) == ["sleep"])

        // A clean one goes without force; a dirty one refuses until forced.
        #expect(await WorktreeScanner.remove(merged, force: false) == nil)
        #expect(!FileManager.default.fileExists(atPath: merged.url.path(percentEncoded: false)))
        #expect(await WorktreeScanner.remove(dirty, force: false) != nil)
        #expect(FileManager.default.fileExists(atPath: dirty.url.path(percentEncoded: false)))
        #expect(await WorktreeScanner.remove(dirty, force: true) == nil)
        // Branches stay.
        let branches = Git.git(["branch", "--format=%(refname:short)"], in: repo).output
        #expect(branches.contains("claude/merged"))
        #expect(branches.contains("dirty"))

        // The main checkout is never removed.
        #expect(await WorktreeScanner.remove(repository.worktrees[0], force: false) != nil)
    }

    @Test func realPathKeepsPrivateLikeLsof() {
        // lsof reports /private/var/…; Foundation's resolver would drop /private.
        #expect(WorktreeScanner.realPath(URL.temporaryDirectory).hasPrefix("/private/var/"))
        #expect(WorktreeScanner.realPath(URL(filePath: "/tmp")) == "/private/tmp")
    }

    @Test func detectsSquashMergedBranches() async throws {
        try #require(Git.path != nil)
        let root = URL.temporaryDirectory.appending(path: "clove-sq-\(UUID().uuidString)").resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = root.appending(path: "projects/app")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-q", "-b", "main"], in: repo)
        try git(["config", "user.email", "test@example.com"], in: repo)
        try git(["config", "user.name", "Test"], in: repo)
        try Data("one".utf8).write(to: repo.appending(path: "README.md"))
        try git(["add", "."], in: repo)
        try git(["commit", "-q", "-m", "first"], in: repo)

        let feature = root.appending(path: "feature")
        try git(["worktree", "add", "-q", "-b", "feature", feature.path(percentEncoded: false)], in: repo)
        try Data("a".utf8).write(to: feature.appending(path: "a.txt"))
        try git(["add", "."], in: feature)
        try git(["commit", "-q", "-m", "a"], in: feature)
        try git(["merge", "-q", "--squash", "feature"], in: repo)
        try git(["commit", "-q", "-m", "squashed"], in: repo)

        let repositories = await WorktreeScanner.scan(projectContainers: [root.appending(path: "projects")], home: root)
        let worktree = try #require(repositories.first?.linked.first)
        #expect(worktree.ahead == 1)
        #expect(worktree.isMerged)
    }
}
